import axios from "axios";
import React, { useEffect, useRef, useState } from "react";
import {
  Card,
  Col,
  Container,
  OverlayTrigger,
  Row,
  Tooltip,
} from "react-bootstrap";
import {
  searchMessage,
  SearchMessageResultType,
} from "../../utils/searchMessage";
import "./HomeSearchResult.scss";

function HomeSearchResultImage(dto: { result: SearchMessageResultType }) {
  const [isLoading, setIsLoading] = useState(true);
  const [imageUrl, setImageUrl] = useState("");
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

function NavigateButton(dto: {
  tooltip: string;
  alphabet: string;
  background: string;
  color: string;
  url: string;
}) {
  return (
    <OverlayTrigger
      overlay={<Tooltip id="tooltip-disabled">{dto.tooltip}</Tooltip>}
    >
      <a
        href={dto.url}
        target="_blank"
        rel="noreferrer"
        style={{ textDecoration: "none" }}
      >
        <div
          className="site-icon"
          style={{
            width: 28,
            height: 28,
            borderRadius: "18%",
            margin: "0 4px 0 0",
            background: dto.background,
            color: dto.color,
            padding: "1px 0 0 0",
          }}
        >
          {dto.alphabet}
        </div>
      </a>
    </OverlayTrigger>
  );
}

function BookmarkOutline() {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="20"
      height="20"
      fill="black"
      viewBox="0 0 16 16"
      style={{
        padding: "0 0 2px 0",
      }}
    >
      <path d="M2 4a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v11.5a.5.5 0 0 1-.777.416L7 13.101l-4.223 2.815A.5.5 0 0 1 2 15.5V4zm2-1a1 1 0 0 0-1 1v10.566l3.723-2.482a.5.5 0 0 1 .554 0L11 14.566V4a1 1 0 0 0-1-1H4z" />
      <path d="M4.268 1H12a1 1 0 0 1 1 1v11.768l.223.148A.5.5 0 0 0 14 13.5V2a2 2 0 0 0-2-2H6a2 2 0 0 0-1.732 1z" />
    </svg>
  );
}

function BookmarkFill() {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="20"
      height="20"
      fill="currentColor"
      viewBox="0 0 16 16"
    >
      <path d="M2 4a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v11.5a.5.5 0 0 1-.777.416L7 13.101l-4.223 2.815A.5.5 0 0 1 2 15.5V4z" />
      <path d="M4.268 1A2 2 0 0 1 6 0h6a2 2 0 0 1 2 2v11.5a.5.5 0 0 1-.777.416L13 13.768V2a1 1 0 0 0-1-1H4.268z" />
    </svg>
  );
}

function BookmarkButton(dto: { e: SearchMessageResultType, keyword: string }) {
  const [bookmarked, setBookmarked] = useState(false);
  const [readyToBookmarked, setReadyToBookmarked] = useState(false);

  useEffect(() => {
    if (readyToBookmarked) return;
    axios.post("/isbookmarked", dto.e).then((e) => {
      if (parseInt(e.data) > 0)
        setBookmarked(true);
      setReadyToBookmarked(true);
    })
  }, [dto, readyToBookmarked]);

  const toggleBookmarked = (e: any) => {
    if (!bookmarked)
      axios.post("/bookmark", {data: dto.e, search: dto.keyword});
    else
      axios.post("/unbookmark", dto.e);
    setBookmarked(!bookmarked);
  };

  return (
    <OverlayTrigger overlay={<Tooltip id="tooltip-disabled">북마크</Tooltip>}>
      <div
        className="site-icon"
        onClick={toggleBookmarked}
        style={{
          width: 28,
          height: 28,
          borderRadius: "18%",
          margin: "0 4px 0 0",
          background: "white",
          color: "#fd758c",
        }}
      >
       <div style={{
          transform: "translateY(-1px)"}}>
            {bookmarked ? <BookmarkFill/> : <BookmarkOutline />}
         </div> 
      </div>
    </OverlayTrigger>
  );
}

function HomeSearchResultCard(dto: { e: SearchMessageResultType, keyword: string }) {
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
            <div style={{ display: "flex", position: "relative" }}>
              <div>
                Id: {dto.e.Id} (Page: {dto.e.Page + 1}p)
              </div>

              <div
                style={{
                  textAlign: "center",
                  fontWeight: "bold",
                  position: "absolute",
                  top: 0,
                  right: 0,
                  display: "flex",
                }}
              >
                <BookmarkButton e={dto.e} keyword={dto.keyword}/>
              </div>
            </div>
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
                <NavigateButton
                  tooltip="익헨 바로가기"
                  background="#650612"
                  color="#fd758c"
                  alphabet="E"
                  url={`https://exhentai.org/g/${dto.e.Id}/${ehash}`}
                />
                <NavigateButton
                  tooltip="히요비 바로가기"
                  background="pink"
                  color="#fd758c"
                  alphabet="H"
                  url={`https://hiyobi.me/reader/${dto.e.Id}`}
                />
                <NavigateButton
                  tooltip="히토미 바로가기"
                  background="#29313e"
                  color="white"
                  alphabet="L"
                  url={`https://hitomi.la/galleries/${dto.e.Id}.html`}
                />
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
          <HomeSearchResultCard e={e} keyword={savedKeyword} />
        ))}
      </Row>
    </Container>
  );
}
