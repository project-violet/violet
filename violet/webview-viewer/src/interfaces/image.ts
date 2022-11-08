export interface IImageProps {
    src: string;
}

export interface IOnImageError {
    currentTarget: {
        onerror: Function | null;
        src: string;
    };
}
