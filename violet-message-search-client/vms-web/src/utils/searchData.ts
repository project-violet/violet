import axios from "axios";

let searchData: { [key: string]: number };

export async function initSearchData() {
  if (searchData !== undefined)
    return;

  const url = "./SORT-COMBINE.json";
  searchData = (await axios.get(url)).data as { [key: string]: number };
}

export function findSearchItemByPart(part: string): [string, number][] {
  let result: [string, number][] = [];

  if (part.length === 0) {
    Object.entries(searchData).forEach(([key, value]) => {
      result.push([key, value]);
    });
  } else {
    Object.entries(searchData).forEach(([key, value]) => {
      if (key.includes(part)) result.push([key, value]);
    });
  }

  result.sort((x, y) => y[1] - x[1]);
  return result;
}
