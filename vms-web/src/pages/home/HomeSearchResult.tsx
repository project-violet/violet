import axios from "axios";
import React, { useEffect, useRef, useState } from "react";
import { Button, Card, Col, Container, Row } from "react-bootstrap";
import { initSearchData, findSearchItemByPart } from "../../utils/searchData";
import {
  dummyMessageResult,
  searchMessage,
  SearchMessageResultType,
} from "../../utils/searchMessage";
import "./HomeSearchResult.scss";

function HomeSearchResultItem(dto: { result: SearchMessageResultType }) {
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
        <div ref={ref} style={{height: "350px"}}>
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

  useEffect(() => {
    if (savedPage !== dto.page && totalResult.length > 0) {
      setSavedPage(dto.page);
      setResult([]);

      const timeout = setTimeout(() => {
        setResult(totalResult.slice((dto.page - 1) * 20, dto.page * 20));
        if (currentTimeoutId != null) {
          clearTimeout(currentTimeoutId);
        }
      }, 500);

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
        setResult(e.slice((dto.page - 1) * 20, dto.page * 20));
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
        {result.map((e) => {
          return (
            <Col>
              <Card>
                <HomeSearchResultItem result={e} />
                <Card.Body>
                  <Card.Title>
                    Id: {e.Id} (Page: {e.Page + 1}p)
                  </Card.Title>
                  <Card.Text>
                    Score: {e.MatchScore}
                    <br />
                    Correctness: {e.Correctness}
                  </Card.Text>
                </Card.Body>
              </Card>
            </Col>
          );
        })}
      </Row>
    </Container>
  );
}
