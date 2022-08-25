package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"regexp"
	"strconv"
	"time"
)

type Data struct {
	id int
	dt time.Time
}

func ParseJSon(fn string) []Data {
	b, _ := ioutil.ReadFile(fn)
	str := string(b)

	var arr []string
	json.Unmarshal([]byte(str), &arr)

	var result []Data

	r, _ := regexp.Compile("\\((\\d+),([\\w\\-:\\.]+),(\\w+)\\)")
	loc, _ := time.LoadLocation("Asia/Seoul")
	for _, s := range arr {
		re := r.FindStringSubmatch(s)

		t, _ := time.Parse(time.RFC3339, re[2])
		id, _ := strconv.Atoi(re[1])

		result = append(result, Data{id, t.In(loc)})
	}

	return result
}

func main() {
	fmt.Println(len(ParseJSon("viewtime-cache-0.json")))
}
