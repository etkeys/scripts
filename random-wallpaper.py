#!/usr/bin/env python3

import os
import random
import requests
import subprocess

_DOWNLOAD_DIR_ = os.path.join(
        os.environ.get("HOME"),"Pictures","Wallpapers","random")
_CURRENT_FILE_NAME_ = os.path.join(_DOWNLOAD_DIR_, "current")
_DOWNLOAD_DB_ = os.path.join(_DOWNLOAD_DIR_, "history.lst")
_IMAGE_POOLS_ = [
        ('abstract', range(1, 8)),
        ('fantasy', range(1,13)),
        ('landscapescities', range(1,9)),
        ('landscapesnature', range(1,20)),
        ('space', range(1,6))
        ]
_URL_ = 'http://www.mydailywallpaper.com/wallcat/?/?'


def main():
    html = get_images_html()
    sources = get_all_image_sources(html)
    file_path = download_new_image(random.choice(sources))
    set_new_file_as_current(file_path)

def get_images_html():
    cat, subpools = random.choice(_IMAGE_POOLS_)
    pool = random.choice(subpools)
    url = _URL_.replace('?',cat, 1)

    if pool > 1:
        url = url.replace('?', f'index{pool}.html', 1)

    req = requests.get(url)

    if req.status_code != 200:
        req.raise_for_status()

    html = req.text.split('\n')
    htmlimages = next(line for line in html if '/show/?cat' in line)
    return htmlimages

def get_all_image_sources(html):
    result = [] 
    atagpos = 0
    keepgoing = True
    while keepgoing:
        keepgoing, atagpos, atag = try_get_span_of_inner_text(
                html, "<a", ">", True, True, atagpos + 2)

        if keepgoing:
            _, _, hrefval = try_get_span_of_inner_text(
                    atag, "'", "'", False, False)
            imgurl = build_img_url(hrefval)
            
            result.append(imgurl)

    return result

def try_get_span_of_inner_text(
        text, startstr, endstr, incStart, incEnd, startpos=0):

    result = ()

    start = text.find(f"{startstr}", startpos)

    if start > 0:
        end = text.find(f"{endstr}", start + 1)

        if not incStart:
            start += 1

        if incEnd:
            end += 1

        innerText = text[start:end]
        result = (True, start, innerText)
    else:
        result = (False, start, "")

    return result

def build_img_url(href):
    hrefpieces = href.split("&")
    cat = hrefpieces[0].split("=")[1]
    img = hrefpieces[1].split("=")[1]
    url = _URL_.replace("wallcat","wallimg").replace("?",cat,1).replace("?",f"img_{img}",1)

    return (img, url)

def download_new_image(source):
    req = requests.get(source[1])

    if req.status_code != 200:
        req.raise_for_status()

    file_path = os.path.join(_DOWNLOAD_DIR_, source[0])
    with open(file_path, 'wb') as p, open(_DOWNLOAD_DB_, 'a') as db:
        p.write(req.content)
        db.write(source[0] + '\n')

    return file_path

def set_new_file_as_current(file_path):
    output = subprocess.run(
            ["ln","--symbolic","--force","--no-dereference", file_path, _CURRENT_FILE_NAME_],
            timeout=30,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            encoding="UTF-8"
        )
    
if __name__ == '__main__':
    main()
