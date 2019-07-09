# ExHDownloader
Simple CLI tool for downloading the thing you want

## Download

## Usage
First off, you'll need to export your cookie as json format, personally recommending using EditThisCookie to export it, then paste to replace everything in `cookie.json`.
Then either using cmd to call `main.rb`(source) or `ExHDownloader.exe`(release), enter the link and start downloading! That's all, and simple.

## Command Line Options
    Usage: main.rb/ExHDownloader.exe [Download URL] [Options]
    
    -h, --help                       Prints this help
    -v, --version                    Prints current version
        --verbose                    Verbose output
    -t, --timeout=TIMEOUT            Set async download timeout in seconds (default is 10)

example:<br>
`ExHDownloader.exe https://exhentai.org/g/1029646/d6e75efcfc/`<br>
`ExHDownloader.exe https://exhentai.org/g/1029646/d6e75efcfc/ -t 20` // set timeout to 20 seconds
