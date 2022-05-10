import axios from "axios";
import React, { useEffect, useRef, useState } from "react";
import {
  Button,
  Card,
  Col,
  Container,
  OverlayTrigger,
  Row,
  Tooltip,
} from "react-bootstrap";
import { initSearchData, findSearchItemByPart } from "../../utils/searchData";
import {
  dummyMessageResult,
  searchMessage,
  SearchMessageResultType,
} from "../../utils/searchMessage";
import "./HomeSearchResult.scss";

function HomeSearchResultImage(dto: { result: SearchMessageResultType }) {
  const [isLoading, setIsLoading] = useState(true);
  const [imageUrl, setImageUrl] = useState("");
  const [imgHeight, setImageHegiht] = useState(0);
  const [imgWidth, setImageWidth] = useState(0);

  const [width, setWidth] = useState(0);
  const ref = useRef() as React.MutableRefObject<HTMLDivElement>;

  useEffect(() => {
    if (ref.current.getBoundingClientRect().width !== 0) {
      setWidth(ref.current!.getBoundingClientRect().width);
    }
  }, [setWidth, ref]);

  useEffect(() => {
    axios.get(`/imageurl/${dto.result.Id}/${dto.result.Page + 1}`).then((e) => {
      setImageHegiht(e.data.size.height);
      setImageWidth(e.data.size.width);
      setImageUrl("/static/" + e.data.url);
      setIsLoading(false);
    });
  }, [setIsLoading, dto, setImageUrl]);

  const resize = () => {
    const { clientWidth } = ref.current;
    if (clientWidth !== 0) {
      console.log(clientWidth);
      setWidth(clientWidth);
    }
  };

  useEffect(() => {
    window.addEventListener("resize", resize);
    return () => {
      window.removeEventListener("resize", resize);
    };
  });

  function mappingPoint(x: number): number {
    return (x * width) / imgWidth;
  }

  return (
    <>
      {/* https://bootsnipp.com/snippets/50blB */}
      {isLoading ? (
        <div
          ref={ref}
          style={{
            height: "350px",
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
          }}
        >
          <div className="loader"></div>
        </div>
      ) : (
        <div
          ref={ref}
          style={{
            position: "relative",
          }}
        >
          <Card.Img variant="top" src={imageUrl} />
          <div
            className="overlay"
            style={{
              position: "absolute",
              border: "5px solid red",
              left: `${mappingPoint(dto.result.Rect[0]) - 5}px`,
              top: `${mappingPoint(dto.result.Rect[1]) - 5}px`,
              width: `${
                mappingPoint(dto.result.Rect[2]) -
                mappingPoint(dto.result.Rect[0]) +
                10
              }px`,
              height: `${
                mappingPoint(dto.result.Rect[3]) -
                mappingPoint(dto.result.Rect[1]) +
                10
              }px`,
            }}
          ></div>
        </div>
      )}
    </>
  );
}

function HomeSearchResultCard(dto: { e: SearchMessageResultType }) {
  const [artist, setArtist] = useState("");
  const [ehash, setEHash] = useState("");

  useEffect(() => {
    axios.get(`/info/${dto.e.Id}`).then((e) => {
      setEHash(e.data.EHash);
      setArtist((e.data.Artists as string).split("|")[1]);
    });
  }, [dto, setEHash]);

  return (
    <Col>
      <Card>
        <HomeSearchResultImage result={dto.e} />
        <Card.Body>
          <Card.Title>
            Id: {dto.e.Id} (Page: {dto.e.Page + 1}p)
          </Card.Title>
          <Card.Text>
            <div style={{ display: "flex", position: "relative" }}>
              <div>
                Artist: {artist}
                <br />
                Score: {dto.e.MatchScore}
                <br />
                Correctness: {dto.e.Correctness}
              </div>
              <div
                style={{
                  textAlign: "center",
                  fontWeight: "bold",
                  position: "absolute",
                  bottom: 0,
                  right: 0,
                  display: "flex",
                }}
              >
                <OverlayTrigger
                  overlay={
                    <Tooltip id="tooltip-disabled">익헨 바로가기</Tooltip>
                  }
                >
                  <a
                    href={`https://exhentai.org/g/${dto.e.Id}/${ehash}`}
                    target="_blank"
                    rel="noreferrer"
                    style={{ textDecoration: "none" }}
                  >
                    {/* <img
                  className="site-icon"
                  width={28}
                  src={"./logo-hiyobi.png"}
                  alt=""
                  style={{ borderRadius: "18%", margin: "0 4px 0 0" }}
                /> */}
                    <div
                      className="site-icon"
                      style={{
                        width: 28,
                        height: 28,
                        borderRadius: "18%",
                        margin: "0 4px 0 0",
                        background: "#650612",
                        color: "#fd758c",
                        padding: "1px 0 0 0",
                      }}
                    >
                      E
                    </div>
                  </a>
                </OverlayTrigger>
                <OverlayTrigger
                  overlay={
                    <Tooltip id="tooltip-disabled">히요비 바로가기</Tooltip>
                  }
                >
                  <a
                    href={`https://hiyobi.me/reader/${dto.e.Id}`}
                    target="_blank"
                    rel="noreferrer"
                    style={{ textDecoration: "none" }}
                  >
                    {/* <img
                    className="site-icon"
                    width={28}
                    src={"./logo-hiyobi.png"}
                    alt=""
                    style={{ borderRadius: "18%", margin: "0 4px 0 0" }}
                  /> */}
                    <div
                      className="site-icon"
                      style={{
                        width: 28,
                        height: 28,
                        borderRadius: "18%",
                        margin: "0 4px 0 0",
                        background: "pink",
                        color: "#fd758c",
                        padding: "1px 0 0 0",
                      }}
                    >
                      H
                    </div>
                  </a>
                </OverlayTrigger>
                <OverlayTrigger
                  overlay={
                    <Tooltip id="tooltip-disabled">히토미 바로가기</Tooltip>
                  }
                >
                  <a
                    href={`https://hitomi.la/galleries/${dto.e.Id}.html`}
                    target="_blank"
                    rel="noreferrer"
                    style={{ textDecoration: "none" }}
                  >
                    {/* <img
                    className="site-icon"
                    width={28}
                    src={"./logo-hitomi.png"}
                    alt=""
                    style={{ borderRadius: "18%", margin: "0 4px 0 0" }}
                  /> */}
                    <div
                      className="site-icon"
                      style={{
                        width: 28,
                        height: 28,
                        borderRadius: "18%",
                        margin: "0 4px 0 0",
                        background: "#29313e",
                        color: "white",
                        padding: "1px 0 0 0",
                      }}
                    >
                      L
                    </div>
                  </a>
                </OverlayTrigger>
                {/* <img
                  className="site-icon"
                  width={28}
                  src={"./logo-eh.png"}
                  alt=""
                  style={{ borderRadius: "18%" }}
                /> */}
              </div>
            </div>
          </Card.Text>
        </Card.Body>
      </Card>
    </Col>
  );
}

export default function HomeSearchResult(dto: {
  keyword: string;
  page: number;
  searchType: number;
}) {
  const [isLoading, setIsLoading] = useState(true);
  const [savedKeyword, setSavedKeyword] = useState(dto.keyword);
  const [savedPage, setSavedPage] = useState(dto.page);
  const [savedSearchType, setSavedSearchType] = useState(dto.searchType);
  const [totalResult, setTotalResult] = useState<SearchMessageResultType[]>([]);
  const [result, setResult] = useState<SearchMessageResultType[]>([]);
  const [currentTimeoutId, setCurrentTimeoutId] = useState<
    NodeJS.Timeout | undefined
  >();
  const countShowArticleOnOnePage = 8;

  useEffect(() => {
    if (savedPage !== dto.page && totalResult.length > 0) {
      setSavedPage(dto.page);
      setResult([]);

      const timeout = setTimeout(() => {
        setResult(
          totalResult.slice(
            (dto.page - 1) * countShowArticleOnOnePage,
            dto.page * countShowArticleOnOnePage
          )
        );
        if (currentTimeoutId != null) {
          clearTimeout(currentTimeoutId);
        }
      }, 100);

      setCurrentTimeoutId(timeout);
    }
  }, [savedPage, dto.page, totalResult.length, totalResult, currentTimeoutId]);

  useEffect(() => {
    if (
      (isLoading ||
        savedKeyword !== dto.keyword ||
        savedSearchType !== dto.searchType) &&
      dto.keyword !== ""
    ) {
      if (savedKeyword !== dto.keyword) {
        setResult([]);
        setTotalResult([]);
      }

      setSavedKeyword(dto.keyword);
      setSavedSearchType(dto.searchType);
      setIsLoading(false);
      searchMessage(dto.keyword, dto.searchType).then((e) => {
        setTotalResult(e);
        setResult(
          e.slice(
            (dto.page - 1) * countShowArticleOnOnePage,
            dto.page * countShowArticleOnOnePage
          )
        );
      });
    }
  }, [
    dto,
    isLoading,
    setIsLoading,
    savedKeyword,
    setTotalResult,
    savedSearchType,
  ]);

  return (
    <Container>
      <Row xs={1} md={2} xl={2} className="g-4">
        {result.map((e) => (
          <HomeSearchResultCard e={e} />
        ))}
      </Row>
    </Container>
  );
}
