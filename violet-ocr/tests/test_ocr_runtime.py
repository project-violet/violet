import os
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


class OcrRuntimeTests(unittest.TestCase):
    def test_group_into_dialogues_merges_nearby_text(self):
        from ocr_common import group_into_dialogues

        texts = [
            {"text": "hello", "confidence": 0.9, "bbox": [10, 10, 30, 20]},
            {"text": "world", "confidence": 0.8, "bbox": [12, 24, 34, 34]},
            {"text": "far", "confidence": 0.7, "bbox": [500, 500, 520, 520]},
        ]

        dialogues = group_into_dialogues(texts, 800, 800)

        self.assertEqual(dialogues[0]["text"], "hello world")
        self.assertEqual(dialogues[0]["bbox"], [10, 10, 34, 34])
        self.assertEqual(dialogues[1]["text"], "far")

    def test_bootstrap_uses_existing_download_without_download(self):
        from work_plan import bootstrap_work_plan, load_expected_file_counts

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            image_dir = tmp_path / "tmp" / "123"
            image_dir.mkdir(parents=True)
            (image_dir / "0001.webp").write_bytes(b"fake")
            args = type(
                "Args",
                (),
                {
                    "raw_dir": str(tmp_path / "raw"),
                    "tmp_dir": str(tmp_path / "tmp"),
                    "keep_empty_tmp": False,
                    "force_ocr": False,
                    "force_download": False,
                    "max_pages": 500,
                    "retry_failed": True,
                    "failed_ids": str(tmp_path / "works" / "failed_ids.jsonl"),
                },
            )()

            self.assertEqual(load_expected_file_counts(str(tmp_path / "missing.db"), ["123"]), {})
            plan = bootstrap_work_plan(["123"], args, {"123": 1})

        self.assertEqual(plan.download_ids, [])
        self.assertEqual(len(plan.existing_downloads), 1)
        self.assertEqual(plan.existing_downloads[0].work_id, "123")

    def test_fast_dl_runner_builds_go_command(self):
        from fast_dl_runner import build_fast_dl_command

        cmd = build_fast_dl_command(
            go_downloader="..\\fast-dl\\fast-dl.exe",
            work_id="123",
            output_root="tmp",
            gallery_dl="gallery-dl",
            file_workers=16,
            file_retries=5,
            max_pages=200,
        )

        self.assertEqual(cmd[0], "..\\fast-dl\\fast-dl.exe")
        self.assertIn("-download-work", cmd)
        self.assertIn("123", cmd)
        self.assertIn("-tmp-dir", cmd)
        self.assertIn("tmp", cmd)


if __name__ == "__main__":
    unittest.main()
