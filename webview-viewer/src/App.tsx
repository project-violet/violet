import "./App.css";
import styled from "styled-components";

const MyImage = styled.img`
  width: 100%;
  padding: 0;
  margin: 0;
  display: block;
  min-width: 300px;
`;

function App() {
  return (
    <>
      <div>
        <MyImage src="/test-article/1.webp" />
        <MyImage src="/test-article/2.webp" />
        <MyImage src="/test-article/3.webp" />
        <MyImage src="/test-article/4.webp" />
        <MyImage src="/test-article/5.webp" />
        <MyImage src="/test-article/6.webp" />
      </div>
    </>
  );
}

export default App;
