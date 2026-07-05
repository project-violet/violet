#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import sqlite3
from collections import OrderedDict, defaultdict
from contextlib import closing
from pathlib import Path
from typing import Iterable, NamedTuple


AUTHOR_WORK_HEADER = [
    "author_key",
    "author_name",
    "article_id",
    "article_artist_count",
    "contribution_weight",
]

AUTHOR_SUMMARY_HEADER = [
    "author_key",
    "author_name",
    "work_count",
    "total_contribution",
]


class AuthorWorkRow(NamedTuple):
    author_key: str
    author_name: str
    article_id: int
    article_artist_count: int
    contribution_weight: float


class AuthorSummaryRow(NamedTuple):
    author_key: str
    author_name: str
    work_count: int
    total_contribution: float


class ExportStats(NamedTuple):
    author_count: int
    row_count: int


def parse_pipe_tags(value: str | None) -> list[str]:
    if not value:
        return []
    return [part.strip() for part in value.split("|") if part.strip()]


def normalize_author_key(author: str) -> str:
    return " ".join(author.replace("_", " ").strip().lower().split())


def unique_author_entries(artists: str | None) -> OrderedDict[str, str]:
    entries: OrderedDict[str, str] = OrderedDict()
    for author_name in parse_pipe_tags(artists):
        author_key = normalize_author_key(author_name)
        if author_key and author_key not in entries:
            entries[author_key] = author_name
    return entries


def read_author_work_rows(db_path: Path) -> list[AuthorWorkRow]:
    rows: list[AuthorWorkRow] = []
    with closing(sqlite3.connect(db_path)) as conn:
        cursor = conn.execute(
            """
            SELECT Id, Artists
            FROM HitomiColumnModel
            WHERE ExistOnHitomi = 1
              AND Artists IS NOT NULL
              AND Artists != ''
            ORDER BY Id
            """
        )
        for article_id, artists in cursor:
            authors = unique_author_entries(artists)
            if not authors:
                continue
            article_artist_count = len(authors)
            contribution_weight = 1.0 / article_artist_count
            for author_key, author_name in authors.items():
                rows.append(
                    AuthorWorkRow(
                        author_key=author_key,
                        author_name=author_name,
                        article_id=int(article_id),
                        article_artist_count=article_artist_count,
                        contribution_weight=contribution_weight,
                    )
                )
    return rows


def filter_rows_by_min_works(rows: Iterable[AuthorWorkRow], min_works: int) -> list[AuthorWorkRow]:
    grouped: dict[str, list[AuthorWorkRow]] = defaultdict(list)
    for row in rows:
        grouped[row.author_key].append(row)
    filtered: list[AuthorWorkRow] = []
    for author_key in sorted(grouped):
        author_rows = sorted(grouped[author_key], key=lambda row: (row.article_id, row.author_name))
        if len(author_rows) >= min_works:
            filtered.extend(author_rows)
    return filtered


def summarize_author_rows(rows: Iterable[AuthorWorkRow]) -> list[AuthorSummaryRow]:
    grouped: dict[str, list[AuthorWorkRow]] = defaultdict(list)
    for row in rows:
        grouped[row.author_key].append(row)
    summaries: list[AuthorSummaryRow] = []
    for author_key in sorted(grouped):
        author_rows = grouped[author_key]
        summaries.append(
            AuthorSummaryRow(
                author_key=author_key,
                author_name=author_rows[0].author_name,
                work_count=len(author_rows),
                total_contribution=sum(row.contribution_weight for row in author_rows),
            )
        )
    return summaries


def format_weight(value: float) -> str:
    if value.is_integer():
        return f"{value:.1f}"
    return f"{value:.12g}"


def write_author_work_csv(path: Path, rows: Iterable[AuthorWorkRow]) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(AUTHOR_WORK_HEADER)
        for row in rows:
            writer.writerow(
                [
                    row.author_key,
                    row.author_name,
                    row.article_id,
                    row.article_artist_count,
                    format_weight(row.contribution_weight),
                ]
            )
            count += 1
    return count


def write_author_summary_csv(path: Path, rows: Iterable[AuthorSummaryRow]) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(AUTHOR_SUMMARY_HEADER)
        for row in rows:
            writer.writerow(
                [
                    row.author_key,
                    row.author_name,
                    row.work_count,
                    format_weight(row.total_contribution),
                ]
            )
            count += 1
    return count


def export_author_work_map(
    db_path: Path,
    output_path: Path,
    summary_output_path: Path | None = None,
    min_works: int = 1,
) -> ExportStats:
    if min_works < 1:
        raise ValueError("min_works must be >= 1")
    rows = filter_rows_by_min_works(read_author_work_rows(db_path), min_works)
    row_count = write_author_work_csv(output_path, rows)
    summaries = summarize_author_rows(rows)
    if summary_output_path is not None:
        write_author_summary_csv(summary_output_path, summaries)
    return ExportStats(author_count=len(summaries), row_count=row_count)


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed < 1:
        raise argparse.ArgumentTypeError("must be >= 1")
    return parsed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Export author-to-work rows from a Violet content SQLite database."
    )
    parser.add_argument("--db", required=True, type=Path, help="Path to content SQLite database.")
    parser.add_argument("--output", required=True, type=Path, help="Output author_work CSV path.")
    parser.add_argument(
        "--summary-output",
        type=Path,
        help="Optional output author_summary CSV path.",
    )
    parser.add_argument(
        "--min-works",
        type=positive_int,
        default=1,
        help="Drop authors with fewer than this many works. Default: 1.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    stats = export_author_work_map(
        db_path=args.db,
        output_path=args.output,
        summary_output_path=args.summary_output,
        min_works=args.min_works,
    )
    print(
        f"wrote {stats.row_count} author-work rows "
        f"for {stats.author_count} authors to {args.output}"
    )
    if args.summary_output is not None:
        print(f"wrote author summary to {args.summary_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
