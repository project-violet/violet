# This source code is a part of Project Violet.
# Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

# GCP에서 Bookmark Crop Event 추출해서 Assets Update 해주는 스크립트

import datetime
import json
import os

from google.cloud import bigquery

# pip install --upgrade google-api-python-client
# pip install google.cloud.bigquery
# https://cloud.google.com/docs/authentication/end-user
# gcloud auth application-default login

client = bigquery.Client()

query = """
SELECT
  event_timestamp,
  (SELECT param.value.string_value
   FROM UNNEST(event_params) AS param
   WHERE param.key = 'Area') as area,
  (SELECT param.value.double_value
   FROM UNNEST(event_params) AS param
   WHERE param.key = 'AspectRatio') as aspect_ratio,
  (SELECT param.value.int_value
   FROM UNNEST(event_params) AS param
   WHERE param.key = 'Article') as article,
  (SELECT param.value.int_value
   FROM UNNEST(event_params) AS param
   WHERE param.key = 'Page') as page,
FROM
  `real-violet-app.analytics_238885015.events_*`
WHERE
  event_name = "bookmark_crop"
LIMIT
  5000
"""

datas = []
dedups = {}
for row in client.query_and_wait(query):
    data = {
        "area": row["area"],
        "aspectRatio": row["aspect_ratio"],
        "article": row["article"],
        "page": row["page"],
    }
    dedup = json.dumps(data)
    if dedup not in dedups:
        dedups[dedup] = True
        data["datetime"] = str(
            datetime.datetime.fromtimestamp(row["event_timestamp"] / 1000 / 1000)
        )
        datas.append(data)

datas = sorted(datas, key=lambda x: x["datetime"])

print(len(datas))

filename = "assets/daily/crop-bookmarks.json"
os.makedirs(os.path.dirname(filename), exist_ok=True)
with open(filename, "w") as file:
    file.write(json.dumps(datas))
