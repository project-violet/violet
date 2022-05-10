import axios from "axios";

export const dummyMessageResult = [
  {
    MatchScore: "100",
    Id: 1228171,
    Page: 11,
    Correctness: 0.9962,
    Rect: [1643, 659, 1711, 703],
  },
  {
    MatchScore: "100",
    Id: 1195559,
    Page: 20,
    Correctness: 0.996338,
    Rect: [174, 635, 327, 709],
  },
  {
    MatchScore: "100",
    Id: 1024644,
    Page: 207,
    Correctness: 0.831191,
    Rect: [336.318, 3.8599, 406.682, 56.1401],
  },
  {
    MatchScore: "100",
    Id: 1165419,
    Page: 2,
    Correctness: 0.393212,
    Rect: [151, 189, 224, 240],
  },
  {
    MatchScore: "100",
    Id: 1000411,
    Page: 0,
    Correctness: 0.969067,
    Rect: [171, 741, 343, 827],
  },
  {
    MatchScore: "100",
    Id: 1122170,
    Page: 0,
    Correctness: 0.820674,
    Rect: [194, 12, 242, 42],
  },
  {
    MatchScore: "100",
    Id: 1204253,
    Page: 34,
    Correctness: 0.998829,
    Rect: [89, 940, 201, 996],
  },
  {
    MatchScore: "100",
    Id: 1333582,
    Page: 72,
    Correctness: 0.997999,
    Rect: [1018.16, 1557.05, 1157.84, 1659.95],
  },
  {
    MatchScore: "100",
    Id: 1390815,
    Page: 33,
    Correctness: 0.416517,
    Rect: [1403.95, 353.067, 1563.05, 464.933],
  },
  {
    MatchScore: "100",
    Id: 1334770,
    Page: 4,
    Correctness: 0.999176,
    Rect: [1855, 2364, 1980, 2437],
  },
  {
    MatchScore: "100",
    Id: 1333582,
    Page: 73,
    Correctness: 0.996124,
    Rect: [1017.13, 1557.05, 1158.87, 1660.95],
  },
  {
    MatchScore: "100",
    Id: 1085704,
    Page: 0,
    Correctness: 0.923964,
    Rect: [848, 34, 988, 136],
  },
  {
    MatchScore: "100",
    Id: 1070895,
    Page: 1,
    Correctness: 0.999488,
    Rect: [157.757, 695.815, 327.243, 823.185],
  },
  {
    MatchScore: "100",
    Id: 1070895,
    Page: 0,
    Correctness: 0.999488,
    Rect: [157.757, 695.815, 327.243, 823.185],
  },
  {
    MatchScore: "100",
    Id: 1077375,
    Page: 19,
    Correctness: 0.761893,
    Rect: [1359, 1823, 1499, 1936],
  },
  {
    MatchScore: "100",
    Id: 1084732,
    Page: 8,
    Correctness: 0.997238,
    Rect: [1059, 1411, 1111, 1447],
  },
];

export interface SearchMessageResultType {
  MatchScore: string,
  Id: number,
  Page: number,
  Correctness: number,
  Rect: [number, number, number, number],
}

export async function searchMessage(keyword: string, searchType: number): Promise<SearchMessageResultType[]> {
  // return dummyMessageResult as SearchMessageResultType[];
  const url = `/search/${['contains', 'similar', 'lcs'][searchType]}/${keyword}`;
  return (await axios.get(url)).data as SearchMessageResultType[];
}
