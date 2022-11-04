import "./App.css";
import styled from "styled-components";
import { useRef, useState } from "react";

const MyImage = styled.img`
  width: 100%;
  padding: 0;
  margin: 0;
  display: block;
`;

// Object.defineProperty(window, "imageset", {
//   value: ["sex"],
//   writable: false,
// });

function getImageSet(): string[] {
  if ((globalThis as any)["imageset"] !== undefined) {
    return (window as any)["imageset"];
  }

  return [
    "/test-article/1.webp",
    "/test-article/2.webp",
    "/test-article/3.webp",
    "/test-article/4.webp",
    "/test-article/5.webp",
    "/test-article/6.webp",
  ];
}

function Image(props: { src: string }) {
  const { src } = props;
  const [minHeight, setMinHeight] = useState(300);
  const img = useRef<HTMLImageElement>(null);

  function onLoad(event: any) {
    setMinHeight(0);
  }

  return (
    <MyImage
      ref={img}
      src={src}
      onLoad={onLoad}
      style={{ minHeight: `${minHeight}px` }}
    />
  );
}

function App() {
  const images = getImageSet();

  return (
    <>
      <div>
        {images.map((e) => (
          <Image src={e} />
        ))}
      </div>
    </>
  );
}

export default App;
