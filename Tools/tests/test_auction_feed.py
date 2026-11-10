"""Tests for Tools/build/auction_feed.py, offline. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import io
import os
import sys
import tempfile
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import auction_feed  # noqa: E402


class AuctionFeedTest(unittest.TestCase):
    def test_lowest_price_for_one(self):
        auctions = [{"item": {"id": 2589}, "quantity": 20, "buyout": 600},
                    {"item": {"id": 2589}, "quantity": 5, "buyout": 125},
                    {"item": {"id": 2770}, "quantity": 1, "bid": 50},
                    {"item": {"id": 4306}, "quantity": 1, "buyout": 900}]
        commodities = [{"item": {"id": 2589}, "quantity": 100, "unit_price": 24},
                       {"item": {"id": 2770}, "quantity": 3, "unit_price": 68}]
        listed = {}
        prices = auction_feed.lowest(commodities, auction_feed.lowest(auctions, {}, listed), listed)
        self.assertEqual(prices, {2589: 24, 2770: 68, 4306: 900})
        self.assertEqual(listed, {2589: 3, 2770: 1, 4306: 1})

    def test_no_listings(self):
        self.assertEqual(auction_feed.lowest(None, {}), {})

    def test_encode_steps_in_base_36(self):
        self.assertEqual(auction_feed.encode({2770: 68, 2589: 26, 2592: 1296}), "1zx:q,3:100,4y:1w")
        self.assertEqual(auction_feed.encode({}), "")

    def test_encode_how_many_are_listed(self):
        self.assertEqual(auction_feed.encode({2589: 26, 2592: 1296}, {2589: 125}), "1zx:q:3h,3:100")

    def test_lua(self):
        feed = {"us": {110: {"faction": "Alliance", "prices": {10: 35}, "listed": {10: 40}},
                       112: {"faction": "Alliance", "prices": {}}}}
        text = auction_feed.lua(feed, 1794114010)
        self.assertIn("    time = 1794114010,\r\n", text)
        self.assertIn('        [1] = {\r\n            [110] = { faction = "Alliance", prices = "a:z:14" },\r\n', text)
        self.assertIn('            [112] = { faction = "Alliance", prices = "" },\r\n', text)
        self.assertTrue(text.isascii())

    def test_last_modified_in_seconds(self):
        self.assertEqual(auction_feed.seconds("Sun, 08 Nov 2026 20:41:07 GMT"), 1794170467)


class FetchTest(unittest.TestCase):
    def setUp(self):
        self.request = urllib.request.Request("https://example.invalid/auctions")
        patcher = mock.patch.object(auction_feed.time, "sleep")
        self.sleep = patcher.start()
        self.addCleanup(patcher.stop)

    def answers(self, *outcomes):
        def urlopen(request, timeout):
            outcome = outcomes[self.calls]
            self.calls += 1
            if isinstance(outcome, Exception):
                raise outcome
            response = mock.MagicMock()
            response.__enter__.return_value = response
            response.read.return_value, response.headers = outcome, {"Last-Modified": "x"}
            return response
        self.calls = 0
        return mock.patch.object(auction_feed.urllib.request, "urlopen", urlopen)

    def http_error(self, code):
        return urllib.error.HTTPError(self.request.full_url, code, "error", {}, io.BytesIO())

    def test_tries_again_after_a_dropped_connection_and_a_5xx(self):
        with self.answers(ConnectionResetError(), self.http_error(503), b"body"), \
                mock.patch("sys.stderr", io.StringIO()):
            self.assertEqual(auction_feed.fetch(self.request)[0], b"body")
        self.assertEqual(self.calls, 3)

    def test_gives_up_after_the_last_try(self):
        with self.answers(TimeoutError(), TimeoutError(), TimeoutError()), mock.patch("sys.stderr", io.StringIO()):
            self.assertRaises(TimeoutError, auction_feed.fetch, self.request)
        self.assertEqual(self.calls, 3)

    def test_never_tries_a_refusal_again(self):
        with self.answers(self.http_error(401)):
            self.assertRaises(urllib.error.HTTPError, auction_feed.fetch, self.request)
        self.assertEqual(self.calls, 1)


class AuctionFeedWriteTest(unittest.TestCase):
    def build(self, found, out):
        argv = ["auction_feed.py", "--region", "us", "--out", str(out)]
        with mock.patch.dict(os.environ, {"BLIZZARD_CLIENT_ID": "id", "BLIZZARD_CLIENT_SECRET": "secret"}),                 mock.patch.object(auction_feed, "token", return_value="access"),                 mock.patch.object(auction_feed, "houses", return_value=found),                 mock.patch.object(sys, "argv", argv), mock.patch("sys.stdout", io.StringIO()):
            auction_feed.main()

    def test_a_region_with_no_prices_writes_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "Prices.lua"
            for found in ({}, {112: {"faction": "Alliance", "prices": {}, "time": 100}}):
                with self.assertRaisesRegex(SystemExit, "no auction prices"):
                    self.build(found, out)
            self.assertFalse(out.exists())

    def test_time_is_the_oldest_house_with_prices(self):
        found = {110: {"faction": "Alliance", "prices": {10: 35}, "time": 300},
                 111: {"faction": "Horde", "prices": {10: 36}, "time": 200},
                 112: {"faction": "Alliance", "prices": {}, "time": 100}}
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "Prices.lua"
            self.build(found, out)
            self.assertIn(b"    time = 200,\r\n", out.read_bytes())


if __name__ == "__main__":
    unittest.main()
