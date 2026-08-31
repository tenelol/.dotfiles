#!/usr/bin/env python3
"""LINEのテキスト書き出しから、指定話者の非可逆な文体統計だけを出力する。"""

from __future__ import annotations

import argparse
import json
import re
import statistics
from collections import Counter
from pathlib import Path


MESSAGE_RE = re.compile(
    r"^(?P<time>\d{1,2}:\d{2})(?:\t(?P<tab_speaker>[^\t]+)\t| (?P<space_speaker>\S+) )(?P<text>.*)$"
)
DATE_RE = re.compile(r"^\d{4}[/.\-]\d{1,2}[/.\-]\d{1,2}")
PLACEHOLDERS = {
    "[スタンプ]",
    "[写真]",
    "[動画]",
    "[ファイル]",
    "[ボイスメッセージ]",
    "スタンプ",
    "画像",
    "写真",
    "動画",
    "ファイル",
    "ボイスメッセージ",
    "メッセージの送信を取り消しました",
}


def parse_messages(text: str) -> list[dict[str, str]]:
    messages: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    current_date = ""

    for raw_line in text.splitlines():
        line = raw_line.rstrip("\r")
        if DATE_RE.match(line):
            current_date = line
            current = None
            continue

        match = MESSAGE_RE.match(line)
        if match:
            speaker = match.group("tab_speaker") or match.group("space_speaker")
            current = {
                "date": current_date,
                "time": match.group("time"),
                "speaker": speaker.strip(),
                "text": match.group("text").strip(),
            }
            messages.append(current)
        elif current is not None and line:
            current["text"] += "\n" + line

    return messages


def time_bucket(value: str) -> str:
    hour = int(value.split(":", 1)[0])
    if 5 <= hour < 12:
        return "朝(05-11)"
    if 12 <= hour < 17:
        return "昼(12-16)"
    if 17 <= hour < 24:
        return "夜(17-23)"
    return "深夜(00-04)"


def ending_ngrams(messages: list[str]) -> list[tuple[str, int]]:
    counter: Counter[str] = Counter()
    for message in messages:
        normalized = re.sub(r"[\s。．.!！?？〜～…・]+$", "", message)
        if not normalized:
            continue
        for size in (2, 3, 4):
            if len(normalized) >= size:
                counter[normalized[-size:]] += 1
    return [(value, count) for value, count in counter.most_common(12) if count >= 2]


def ratio(matches: int, total: int) -> float:
    return round(matches / total, 3) if total else 0


def summarize(messages: list[dict[str, str]], speaker: str) -> dict[str, object]:
    selected = [m for m in messages if m["speaker"] == speaker]
    text_messages = [
        m for m in selected if m["text"] and m["text"] not in PLACEHOLDERS
    ]
    texts = [m["text"] for m in text_messages]
    lengths = [len(text) for text in texts]
    media_count = len(selected) - len(text_messages)
    buckets = Counter(time_bucket(m["time"]) for m in selected)

    return {
        "speaker": speaker,
        "parsed_all_messages": len(messages),
        "speaker_messages": len(selected),
        "text_messages": len(text_messages),
        "media_or_system_placeholders": media_count,
        "date_headers": len({m["date"] for m in selected if m["date"]}),
        "length_chars": {
            "median": statistics.median(lengths) if lengths else 0,
            "mean": round(statistics.mean(lengths), 1) if lengths else 0,
            "max": max(lengths, default=0),
        },
        "single_line_ratio": ratio(sum("\n" not in text for text in texts), len(texts)),
        "question_ratio": ratio(
            sum(bool(re.search(r"[?？]", text)) for text in texts), len(texts)
        ),
        "exclamation_ratio": ratio(
            sum(bool(re.search(r"[!！]", text)) for text in texts), len(texts)
        ),
        "time_buckets": dict(buckets),
        "repeated_endings": ending_ngrams(texts),
        "privacy": "原文メッセージは出力していません",
    }


def render_markdown(summary: dict[str, object]) -> str:
    lengths = summary["length_chars"]
    lines = [
        f"# LINE文体集計: {summary['speaker']}",
        "",
        f"- 全メッセージ: {summary['parsed_all_messages']}",
        f"- 本人メッセージ: {summary['speaker_messages']}",
        f"- 本文メッセージ: {summary['text_messages']}",
        f"- 文字数中央値 / 平均 / 最大: {lengths['median']} / {lengths['mean']} / {lengths['max']}",
        f"- 1行率: {summary['single_line_ratio']}",
        f"- 疑問符率: {summary['question_ratio']}",
        f"- 感嘆符率: {summary['exclamation_ratio']}",
        f"- 時間帯: {summary['time_buckets']}",
        f"- 反復する文末断片: {summary['repeated_endings']}",
        f"- プライバシー: {summary['privacy']}",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export", type=Path, help="LINEから書き出したTXT")
    parser.add_argument("--speaker", default="ゆぅき", help="本人の表示名")
    parser.add_argument("--json", action="store_true", help="JSONで出力")
    args = parser.parse_args()

    raw = args.export.read_text(encoding="utf-8-sig")
    summary = summarize(parse_messages(raw), args.speaker)
    if summary["speaker_messages"] == 0:
        raise SystemExit(
            f"話者 {args.speaker!r} のメッセージが見つかりません。表示名を確認してください。"
        )
    if args.json:
        print(json.dumps(summary, ensure_ascii=False, indent=2))
    else:
        print(render_markdown(summary))


if __name__ == "__main__":
    main()
