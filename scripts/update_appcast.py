#!/usr/bin/env python3
"""
Appends a new release item to appcast.xml.

Usage:
    python3 scripts/update_appcast.py \
        --version 0.0.1 \
        --build 42 \
        --url https://github.com/DanLopess/openauris/releases/download/v0.0.1/OpenAuris-0.0.1.zip \
        --signature <ed25519-base64-signature> \
        --zip-path /path/to/OpenAuris-0.0.1.zip
"""
import argparse
import os
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
DC_NS = "http://purl.org/dc/elements/1.1/"

ET.register_namespace("sparkle", SPARKLE_NS)
ET.register_namespace("dc", DC_NS)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--signature", required=True)
    parser.add_argument("--zip-path", required=True)
    args = parser.parse_args()

    file_size = os.path.getsize(args.zip_path)
    pub_date = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")

    tree = ET.parse("appcast.xml")
    root = tree.getroot()
    channel = root.find("channel")

    item = ET.Element("item")

    title_el = ET.SubElement(item, "title")
    title_el.text = f"Version {args.version}"

    date_el = ET.SubElement(item, "pubDate")
    date_el.text = pub_date

    enc = ET.SubElement(item, "enclosure")
    enc.set("url", args.url)
    enc.set("type", "application/octet-stream")
    enc.set("length", str(file_size))
    enc.set(f"{{{SPARKLE_NS}}}version", args.build)
    enc.set(f"{{{SPARKLE_NS}}}shortVersionString", args.version)
    enc.set(f"{{{SPARKLE_NS}}}edSignature", args.signature)

    first_item = channel.find("item")
    if first_item is not None:
        idx = list(channel).index(first_item)
        channel.insert(idx, item)
    else:
        channel.append(item)

    ET.indent(tree, space="  ")
    tree.write("appcast.xml", encoding="unicode", xml_declaration=True)
    print(f"appcast.xml updated with version {args.version} (build {args.build})")


if __name__ == "__main__":
    main()
