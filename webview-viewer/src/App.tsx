import './App.css';
import { Image } from './components/image';
import { getImageSet } from './utils/image-set';

export default function App() {
    const images = getImageSet();

    return (
        <div>
            {images.map((e) => (
                <Image key={e} src={e} />
            ))}
        </div>
    );
}
