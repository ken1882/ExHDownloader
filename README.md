# ExHDownloader
簡單的熊貓網下載器<br>
Simple CLI tool for downloading the thing you want

## 下載 | Download
https://github.com/ken1882/ExHDownloader/releases

## 使用方式 | Usage
### 繁體中文:
此工具不需輸入帳號密碼，但是需要Cookie才能成功連上熊貓網站，輸出Cookie推薦使用[EditThisCookie](https://chrome.google.com/webstore/detail/editthiscookie/fngmhnnpilhplaeedifhccceomclgfbg)輸出(Export)，成功進入熊貓網後點選擴充功能 -> "Export"之後便會將Cookie複製，接著到`cookie.json`貼上並取代原本內容即可。
當Cookie準備好之後，只要點兩下等待初始化一陣子後再輸入本本頁面網站即可開始下載、或者使用cmd輸入`main.rb`(原始碼) or `ExHDownloader.exe`(公開使用版)亦可。
※請勿將Cookie與他人分享，駭客可以使用這些資料來登入你的熊貓網站!

### English:
First off, you'll need to export your cookie as json format, personally recommending using [EditThisCookie](https://chrome.google.com/webstore/detail/editthiscookie/fngmhnnpilhplaeedifhccceomclgfbg) to export it, then paste to replace everything in `cookie.json`.
After you have set the cookie correctly, either using cmd to call `main.rb`(source) or `ExHDownloader.exe`(release), enter the link and start downloading! That's all, and simple.
※ Do not share your cookie to other 3rd party, hacker may use this to login your account!

## Command Line Options
    Usage: main.rb/ExHDownloader.exe [Download URL] [Options]
    
    -h, --help                       Prints this help
    -v, --version                    Prints current version
        --verbose                    Verbose output
    -t, --timeout=TIMEOUT            Set async download timeout in seconds (default is 10)

example:<br>
`ExHDownloader.exe https://exhentai.org/g/1029646/d6e75efcfc/`<br>
`ExHDownloader.exe https://exhentai.org/g/1029646/d6e75efcfc/ -t 20` // set timeout to 20 seconds
