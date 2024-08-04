# This source code is a part of Project Violet.
# Copyright (C) 2022. violet-team. Licensed under the Apache-2.0 License.

import requests
import sys
import os
import sqlite3

# https://stackoverflow.com/questions/16694907/download-large-file-in-python-with-requests


def download_file(url):
    filename = url.split('/')[-1]
    with open(filename, "wb") as f:
        response = requests.get(url, stream=True)
        total_length = response.headers.get('content-length')

        if total_length is None:  # no content length header
            f.write(response.content)
        else:
            dl = 0
            total_length = int(total_length)
            for data in response.iter_content(chunk_size=4096):
                dl += len(data)
                f.write(data)
                done = int(50 * dl / total_length)
                sys.stdout.write("\r[%s%s] %s" % (
                    '=' * done, ' ' * (50-done), str(round(dl / total_length * 100.0, 2)) + "%"))
                sys.stdout.flush()


if not os.path.isfile("data.db"):
    releases = requests.get(
        'https://api.github.com/repos/violet-dev/sync-data/releases/latest')
    latest_db = releases.json()['assets'][0]['browser_download_url']
    download_file(latest_db)


def show_tables():
    conn = sqlite3.connect("data.db")
    cur = conn.cursor()
    rows = cur.execute("SELECT * FROM sqlite_master WHERE type='table';")
    for row in rows:
        print(row)
    conn.close()


def extract_ids():
    conn = sqlite3.connect("data.db")
    cur = conn.cursor()
    rows = cur.execute(
        "SELECT Id FROM HitomiColumnModel WHERE Language='english' AND ExistOnHitomi=1 AND NOT Type='anime';")
    with open('ids.txt.temp', "w") as f:
        f.write(','.join(map(lambda x: str(x[0]), rows)))
    conn.close()


extract_ids()
