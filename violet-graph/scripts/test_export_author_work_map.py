import csv
import importlib.util
import sqlite3
import tempfile
import unittest
from pathlib import Path


def load_script_module():
    script_path = Path(__file__).with_name("export_author_work_map.py")
    spec = importlib.util.spec_from_file_location("export_author_work_map", script_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ExportAuthorWorkMapTest(unittest.TestCase):
    def test_exports_normalized_author_work_rows_and_summary(self):
        module = load_script_module()
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            db_path = temp_path / "content.db"
            output_path = temp_path / "author_work.csv"
            summary_path = temp_path / "author_summary.csv"

            conn = sqlite3.connect(db_path)
            conn.execute(
                """
                CREATE TABLE HitomiColumnModel (
                    Id INTEGER PRIMARY KEY,
                    Artists TEXT,
                    ExistOnHitomi INTEGER
                )
                """
            )
            conn.executemany(
                "INSERT INTO HitomiColumnModel (Id, Artists, ExistOnHitomi) VALUES (?, ?, ?)",
                [
                    (101, "|Foo_Bar|Other|", 1),
                    (102, "foo bar|Solo", 1),
                    (103, "Hidden", 0),
                    (104, "", 1),
                    (105, "|Foo_Bar|Foo_Bar|", 1),
                ],
            )
            conn.commit()
            conn.close()

            stats = module.export_author_work_map(
                db_path=db_path,
                output_path=output_path,
                summary_output_path=summary_path,
                min_works=2,
            )

            self.assertEqual(stats.author_count, 1)
            self.assertEqual(stats.row_count, 3)
            with output_path.open(newline="", encoding="utf-8") as csv_file:
                rows = list(csv.DictReader(csv_file))

            self.assertEqual(
                rows,
                [
                    {
                        "author_key": "foo bar",
                        "author_name": "Foo_Bar",
                        "article_id": "101",
                        "article_artist_count": "2",
                        "contribution_weight": "0.5",
                    },
                    {
                        "author_key": "foo bar",
                        "author_name": "foo bar",
                        "article_id": "102",
                        "article_artist_count": "2",
                        "contribution_weight": "0.5",
                    },
                    {
                        "author_key": "foo bar",
                        "author_name": "Foo_Bar",
                        "article_id": "105",
                        "article_artist_count": "1",
                        "contribution_weight": "1.0",
                    },
                ],
            )

            with summary_path.open(newline="", encoding="utf-8") as csv_file:
                summary_rows = list(csv.DictReader(csv_file))

            self.assertEqual(
                summary_rows,
                [
                    {
                        "author_key": "foo bar",
                        "author_name": "Foo_Bar",
                        "work_count": "3",
                        "total_contribution": "2.0",
                    }
                ],
            )


if __name__ == "__main__":
    unittest.main()
