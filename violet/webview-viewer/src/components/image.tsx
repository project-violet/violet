import { useRef, useState } from "react";
import { IImageProps } from "../interfaces/image";
import { MyImage } from "../styles";

export function Image({ src }: IImageProps) {
  const [minHeight, setMinHeight] = useState(300);
  const imgRef = useRef<HTMLImageElement>(null);

  function onLoad() {
    setMinHeight(0);
  }

  return (
    <MyImage
      ref={imgRef}
      src={src}
      onLoad={onLoad}
      style={{ minHeight: `${minHeight}px` }}
    />
  );
}