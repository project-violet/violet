package main

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"io/ioutil"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/thoas/go-funk"
)

type Data struct {
	id int
	dt time.Time
}

var datas []Data

func ParseJSon(fn string) []Data {
	b, _ := ioutil.ReadFile(fn)
	str := string(b)

	var arr []string
	json.Unmarshal([]byte(str), &arr)

	var result []Data

	loc, _ := time.LoadLocation("Asia/Seoul")
	for _, s := range arr {
		ss := strings.ReplaceAll(strings.ReplaceAll(s, "(", ""), ")", "")
		re := strings.Split(ss, ",")

		t, _ := time.Parse(time.RFC3339, strings.TrimSpace(re[1]))
		id, _ := strconv.Atoi(re[0])

		result = append(result, Data{id, t.In(loc)})
	}

	return result
}

func LoadDatas() {
	files, _ := ioutil.ReadDir(".")

	fns := funk.Map(funk.Filter(files, func(p fs.FileInfo) bool {
		return strings.HasPrefix(p.Name(), "viewtime-cache-")
	}), func(p fs.FileInfo) string { return p.Name() }).([]string)

	for _, fn := range fns {
		data := ParseJSon(fn)

		datas = append(datas, data...)
	}
}

func SortDatas() {
	sort.Slice(datas, func(i, j int) bool {
		return datas[i].dt.Before(datas[j].dt)
	})
}

func Reduce() []Data {
	var m map[int]map[int]map[int]int
	m = make(map[int]map[int]map[int]int)

	for _, d := range datas {
		yy := d.dt.Year()
		mm := int(d.dt.Month())
		dd := d.dt.Day()

		_, e := m[yy]
		if !e {
			m[yy] = make(map[int]map[int]int)
		}

		_, ee := m[yy][mm]
		if !ee {
			m[yy][mm] = make(map[int]int)
		}

		_, eee := m[yy][mm][dd]
		if !eee {
			m[yy][mm][dd] = 0
		}

		m[yy][mm][dd] += 1
	}

	var result []Data

	for ky, vm := range m {
		for km, vd := range vm {
			for kd, c := range vd {
				result = append(result, Data{c,
					time.Date(ky, time.Month(km), kd, 0, 0, 0, 0, time.UTC)})
			}
		}
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i].dt.Before(result[j].dt)
	})

	return result
}

func main() {
	LoadDatas()
	SortDatas()
	result := Reduce()

	for _, d := range result {
		fmt.Println(d.dt.Year(), int(d.dt.Month()), d.dt.Day(), d.id)
	}
}
