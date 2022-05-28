# https://github.com/Saebasol/tag-info/blob/master/script/auto_complete.py

from json import dumps, loads
import logging
from aiohttp import ClientSession
from asyncio.runners import run
from asyncio.tasks import sleep

logger = logging.getLogger()
logging.basicConfig(level=logging.INFO)

formatter = logging.Formatter("%(asctime)s - (%(name)s) - [%(levelname)s]: %(message)s")

ch = logging.StreamHandler()
ch.setLevel(logging.INFO)
ch.setFormatter(formatter)

fh = logging.FileHandler("auto_complete.log")
fh.setLevel(logging.DEBUG)
fh.setFormatter(formatter)


class Request:
    crawled_dict = {}

    def __init__(self, key) -> None:
        self.key = key
        self.session = None
        self._req_list = []

    def load_character(self):
        logger.info("load series file")
        with open("test2.json", "r", encoding="UTF-8") as f:
            return loads(f.read())
        
    
    async def request(self, query):
        PARAMS = {
            "limit": 1,
            "indent": "true",
            "languages": "ko",
            "key":self.key,
            "query": query
        }
        if not self.session:
            logger.info("Make Session")
            self.session = ClientSession()

        descHubo = ['애니메이션', '게임', 'TV 프로그램', '영화', '만화', '등장', '책']
        bodyHubo = ['라이트 노벨', '게임', '만화', '애니메이션', '소설']
        
        for _ in range(5):
            async with self.session.get("https://kgsearch.googleapis.com/v1/entities:search", params=PARAMS) as response:
                logger.info("get %s", query)
                if response.status == 429:
                    logger.warn("429 sleep")
                    await sleep(30)
                    continue

                logger.info(await response.json())

                if element := (await response.json())["itemListElement"]:
                    result = element[0]["result"]
                    if ((desc := result.get("description")) and any(desc.find(item) != -1 for item in descHubo)) or \
                        ((_ := result.get('detailedDescription')) and (body := result['detailedDescription'].get("articleBody")) and any(body.find(item) != -1 for item in bodyHubo)):
                        logger.info("found korean_name: %s",  result["name"])
                        return {query: result["name"]}
                logger.info("Not found %s", query)
                return {query: ""}

    
    async def __run(self):
        try:
            logger.info("start append task")
            chs = self.load_character()
            for charactor_key in chs:
                if chs[charactor_key] != '':
                    logger.info(chs[charactor_key])
                    continue
                self._req_list.append(self.request(charactor_key))
            logger.info("Complete append task")

            logger.info("Start Tasks")
            # TODO: more faster
            count = 0
            total = len(self._req_list)
            for req in self._req_list:
                count += 1
                logger.info("%s/%s", count, total)
                self.crawled_dict.update(await req)
        finally:
            logger.info("close clientsession")
            await self.session.close()

            with open("acrawled.json", "w") as f:
                logger.info("Saving...")
                f.write(dumps(self.crawled_dict))
                logger.info("Done!")

    def run(self):
        logger.info("Starting")
        run(self.__run())
        logger.info("Done.")


Request("AIzaSyCQYJvJzWy-iUHCi9C6E8o1RpOY5K4ae-8").run()