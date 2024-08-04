import { Fragment, useEffect, useState } from "react";
import {
  Container,
  Dropdown,
  DropdownButton,
  Form,
  InputGroup,
  Navbar,
  OverlayTrigger,
  Pagination,
  Tooltip,
} from "react-bootstrap";
import { AsyncTypeahead } from "react-bootstrap-typeahead";
import { findSearchItemByPart, initSearchData } from "../../utils/searchData";
import HomeNavbar from "./HomeNavbar";
import HomeSearchResult from "./HomeSearchResult";

function HighlightedSearchItem(dto: { option: any; query: string }) {
  const name: string = dto.option.name;
  const count: number = dto.option.count;

  function numberWithCommas(x: number) {
    return x.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  }

  try {
    const s = name.substring(0, name.indexOf(dto.query));
    const c = dto.query;
    const e = name.substring(name.indexOf(dto.query) + dto.query.length);

    return (
      <div style={{ display: "flex", justifyContent: "stretch" }}>
        <div
          style={{
            flexGrow: "1",
            overflow: "hidden",
            textOverflow: "ellipsis",
          }}
        >
          <span style={{ textOverflow: "ellipsis" }}>{s}</span>
          <span style={{ fontWeight: "bold" }}>{c}</span>
          <span style={{ textOverflow: "ellipsis" }}>{e}</span>
        </div>
        <div style={{ flexGrow: "0" }}>{numberWithCommas(count)} 회</div>
      </div>
    );
  } catch (e) {
    return (
      <div style={{ display: "flex", justifyContent: "stretch" }}>
        <div
          style={{
            flexGrow: "1",
            overflow: "hidden",
            textOverflow: "ellipsis",
          }}
        >
          {name}
        </div>
        <div style={{ flexGrow: "0" }}>{numberWithCommas(count)} 회</div>
      </div>
    );
  }
}

function HomePageSearchBar(dto: {
  setKeyword: (keyword: string) => void;
  searchType: number;
  setSearchType: (type: number) => void;
}) {
  const [isLoading, setIsLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(false);
  const [options, setOptions] = useState<any[]>([]);

  useEffect(() => {
    if (isLoading) {
      initSearchData().then(() => {
        setOptions(findSearchItemByPart(""));
      });
      setIsLoading(false);
    }
  }, [isLoading, setIsLoading, setOptions]);

  const handleSearch = (query: string) => {
    const options = findSearchItemByPart(query).map((e) => ({
      name: e[0],
      count: e[1],
    }));

    setOpen(true);
    setQuery(query);
    setOptions(options);
  };

  const filterBy = () => true;

  const onKeyDown = (e: any) => {
    if (e.keyCode === 13) {
      setOpen(false);
      dto.setKeyword(query);
    }
  };

  const onChange = (e: any) => {
    if (e[0] !== undefined) {
      setOpen(false);
      dto.setKeyword(e[0].name);
    }
  };

  return (
    <InputGroup className="mb-3">
      <DropdownButton
        variant="outline-secondary"
        title={["Contains", "Similar", "LCS"][dto.searchType]}
        id="input-group-dropdown-1"
      >
        <OverlayTrigger
          overlay={
            <Tooltip id="tooltip-disabled">
              입력 단어가 포함된 대사를 검색합니다.
            </Tooltip>
          }
        >
          <Dropdown.Item href="#" onClick={(_) => dto.setSearchType(0)}>
            Contains
          </Dropdown.Item>
        </OverlayTrigger>
        <OverlayTrigger
          overlay={
            <Tooltip id="tooltip-disabled">
              입력 문장과 유사한 대사를 검색합니다.
            </Tooltip>
          }
        >
          <Dropdown.Item href="#" onClick={(_) => dto.setSearchType(1)}>
            Similar
          </Dropdown.Item>
        </OverlayTrigger>
        <OverlayTrigger
          overlay={
            <Tooltip id="tooltip-disabled">
              최장 공통 부분 문자열 알고리즘을 이용하여 검색합니다.
            </Tooltip>
          }
        >
          <Dropdown.Item href="#" onClick={(_) => dto.setSearchType(2)}>
            LCS
          </Dropdown.Item>
        </OverlayTrigger>
      </DropdownButton>
      <AsyncTypeahead
        delay={0}
        clearButton
        filterBy={filterBy}
        id="basic-typeahead-single"
        labelKey="name"
        onSearch={handleSearch}
        options={options}
        placeholder="원하는 대사를 검색하세요"
        isLoading={isLoading}
        // className="me-2"
        open={open}
        paginationText="더보기"
        minLength={0}
        onKeyDown={onKeyDown}
        promptText="검색어를 입력하세요"
        onChange={onChange}
        renderMenuItemChildren={(option, props) => (
          <Fragment>
            <HighlightedSearchItem option={option} query={query} />
          </Fragment>
        )}
      />
    </InputGroup>
  );
}

function PaginationBar(dto: {
  curPage: number;
  setCurPage: (page: number) => void;
}) {
  if (dto.curPage <= 5) {
    return (
      <Pagination>
        <Pagination.Prev
          disabled={dto.curPage === 1}
          onClick={(_) => dto.setCurPage(dto.curPage - 1)}
        />

        {range(1, 5).map((e) => {
          return (
            <Pagination.Item
              key={e}
              active={e === dto.curPage}
              onClick={(_) => dto.setCurPage(e)}
            >
              {e}
            </Pagination.Item>
          );
        })}

        {range(6, 7).map((e) => {
          return (
            <Pagination.Item
              key={e}
              active={e === dto.curPage}
              onClick={(_) => dto.setCurPage(e)}
            >
              {e}
            </Pagination.Item>
          );
        })}

        <Pagination.Ellipsis onClick={(_) => dto.setCurPage(8)}/>
        <Pagination.Item onClick={(_) => dto.setCurPage(50)}>{50}</Pagination.Item>
        <Pagination.Next
          disabled={dto.curPage === 50}
          onClick={(_) => dto.setCurPage(dto.curPage + 1)}
        />
      </Pagination>
    );
  } else if (dto.curPage >= 46) {
    return (
      <Pagination>
        <Pagination.Prev
          disabled={dto.curPage === 1}
          onClick={(_) => dto.setCurPage(dto.curPage - 1)}
        />
        <Pagination.Item onClick={(_) => dto.setCurPage(1)}>{1}</Pagination.Item>
        <Pagination.Ellipsis onClick={(_) => dto.setCurPage(43)}/>

        {range(44, 45).map((e) => {
          return (
            <Pagination.Item
              key={e}
              active={e === dto.curPage}
              onClick={(_) => dto.setCurPage(e)}
            >
              {e}
            </Pagination.Item>
          );
        })}

        {range(46, 50).map((e) => {
          return (
            <Pagination.Item
              key={e}
              active={e === dto.curPage}
              onClick={(_) => dto.setCurPage(e)}
            >
              {e}
            </Pagination.Item>
          );
        })}

        <Pagination.Next
          disabled={dto.curPage === 50}
          onClick={(_) => dto.setCurPage(dto.curPage + 1)}
        />
      </Pagination>
    );
  }
   
  return (
    <Pagination>
      <Pagination.Prev
        disabled={dto.curPage === 1}
        onClick={(_) => dto.setCurPage(dto.curPage - 1)}
      />
      <Pagination.Item onClick={(_) => dto.setCurPage(1)}>{1}</Pagination.Item>
      <Pagination.Ellipsis onClick={(_) => dto.setCurPage(dto.curPage - 3)}/>

      {range(dto.curPage - 2, dto.curPage + 2).map((e) => {
        return (
          <Pagination.Item
            key={e}
            active={e === dto.curPage}
            onClick={(_) => dto.setCurPage(e)}
          >
            {e}
          </Pagination.Item>
        );
      })}

      <Pagination.Ellipsis onClick={(_) => dto.setCurPage(dto.curPage + 3)}/>
      <Pagination.Item onClick={(_) => dto.setCurPage(50)}>
        {50}
      </Pagination.Item>
      <Pagination.Next
        disabled={dto.curPage === 50}
        onClick={(_) => dto.setCurPage(dto.curPage + 1)}
      />
    </Pagination>
  );
}

const range = (start: number, stop: number, step: number = 1) =>
  Array.from({ length: (stop - start) / step + 1 }, (_, i) => start + i * step);

export default function HomePage() {
  const [keyword, setKeyword] = useState("");
  const [curPage, setCurPage] = useState(1);
  const [searchType, setSearchType] = useState(0);

  return (
    <div>
      <HomeNavbar />
      <Navbar>
        <Container style={{ display: "block" }}>
          <Form>
            <HomePageSearchBar
              setKeyword={setKeyword}
              searchType={searchType}
              setSearchType={setSearchType}
            />
          </Form>
        </Container>
      </Navbar>
      <HomeSearchResult
        keyword={keyword}
        page={curPage}
        searchType={searchType}
      />
      <div
        style={{
          display: "flex",
          justifyContent: "center",
          width: "100%",
          alignContent: "center",
          margin: "36px 0 0 0",
        }}
      >
        <PaginationBar curPage={curPage} setCurPage={setCurPage} />
      </div>
    </div>
  );
}
