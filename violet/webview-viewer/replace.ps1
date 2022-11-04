Get-Content build\index.html | % { $_ -replace "href=""/", "href=""" }  | % { $_ -replace "src=""/", "src=""" } | Out-File -encoding ASCII build\index1.html
