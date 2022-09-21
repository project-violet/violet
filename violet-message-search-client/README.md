# Violet Message Search Local

![](capture.png)

## How To Use?

1. Install node.js & gallery-dl
2. Extract https://github.com/project-violet/violet-message-search-local/releases/download/0.1/dist.zip
3. Run run.bat, run-server.bat
4. Open http://localhost:6974/home/ in browser!

## Default Settings

```
fscm:
  IP: localhost
  PORT: 8864
vms-server:
  IP: localhost
  PORT: 6974
```

## ElasticSearch Only

```sh
# Set vm.max_map_count to 26144
wsl -d docker-desktop
sysctl -w vm.max_map_count=262144
exit

# Run elasticsearch
docker pull docker.elastic.co/elasticsearch/elasticsearch:8.2.0
docker network create elastic
docker run --name es01 --net elastic -p 9200:9200 -p 9300:9300 -it docker.elastic.co/elasticsearch/elasticsearch:8.2.0

# install CA
docker cp es01:/usr/share/elasticsearch/config/certs/http_ca.crt .

# Test
goto http://localhost:9200/ with u:elastic, p:
```

## ELK

```sh
# up
docker-compose -f ./docker-compose.yml up -d
or
docker-compose up -d

# down
docker-compose down

# elk
curl -XGET http://localhost:9200/_cat/indices?v
curl -XPOST http://localhost:9200/test/_doc/1 -H "Content-Type: application/json" -d @test.json -v
```

## Query

```
{
  "query": {
    "query_string": {
      "default_field": "Message",
      "query": "qhwl"
    }
  },
  "sort": {
    "ArticleId": "desc"
  }
}

GET /test/_search
{
  "query": {
    "fuzzy": {
      "Message": {
        "value": "clsduehdtod",
        "max_expansions": 150
      }
    }
  }
}

GET /test/_search
{
  "query": {
    "multi_match": {
      "query": "duehdtod",
      "fields": ["Message"],
      "fuzziness": 1
    }
  }
}

GET /test/_search
{
  "query": {
    "match": {
      "Message": {
        "query": "dmsrmstmfWjr",
        "fuzziness": "AUTO"
      }
    }
  }
}
```
