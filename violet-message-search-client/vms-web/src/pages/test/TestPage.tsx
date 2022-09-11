import axios from "axios";
import React, { useEffect, useRef, useState } from "react";
import { Card } from "react-bootstrap";
import { useParams } from "react-router";
import {
  dummyMessageRaw,
  SearchMessageRawResultType,
  SearchMessageRectangleType,
} from "../../utils/searchMessage";

function TestSearchResultImage(dto: {
  result: SearchMessageRawResultType;
  rects: SearchMessageRawResultType[];
}) {
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
    axios
      .get(`/imageurl/${dto.result.ArticleId}/${dto.result.Page + 1}`)
      .then((e) => {
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
          {dto.rects.map((e) => (
            <div
              className="overlay"
              title={e.MessageRaw}
              style={{
                position: "absolute",
                border: "5px solid red",
                left: `${mappingPoint(e.Rectangle[0]) - 5}px`,
                top: `${mappingPoint(e.Rectangle[1]) - 5}px`,
                width: `${mappingPoint(e.Rectangle[2]) - mappingPoint(e.Rectangle[0]) + 10}px`,
                height: `${mappingPoint(e.Rectangle[3]) - mappingPoint(e.Rectangle[1]) + 10}px`,
              }}
            ></div>
          ))}
        </div>
      )}
    </>
  );
}

export default function TestPage() {
  const { id, page } = useParams();

  return (
    <div>
      <TestSearchResultImage
        result={
          {
            ArticleId: dummyMessageRaw[0].ArticleId,
            Page: parseInt(page!),
          } as SearchMessageRawResultType
        }
        rects={dummyMessageRaw
          .filter((e) => e.Page === parseInt(page!))}
      />
    </div>
  );
}
