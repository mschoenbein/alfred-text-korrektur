#!/usr/bin/env python3
import sys
import os
import json
import urllib.request
import urllib.parse


def main():
    text = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else ""
    if not text.strip():
        print(text, end="")
        return

    provider = os.environ.get("provider", "ollama")

    try:
        if provider == "languagetool":
            result = correct_languagetool(text)
        elif provider == "mistral":
            result = correct_mistral(text)
        else:
            result = correct_ollama(text)
    except Exception:
        result = text

    print(result, end="")


def correct_ollama(text):
    system_prompt = os.environ.get("system_prompt", "Korrigiere Rechtschreibung und Grammatik.")
    temperature = int(os.environ.get("temperature", "0")) / 10

    payload = {
        "model": "llama3.1",
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": text},
        ],
        "stream": False,
        "options": {"temperature": temperature},
    }

    req = urllib.request.Request(
        "http://localhost:11434/api/chat",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )

    with urllib.request.urlopen(req, timeout=60) as resp:
        data = json.loads(resp.read())

    return data["message"]["content"].strip()


def correct_mistral(text):
    system_prompt = os.environ.get("system_prompt", "Korrigiere Rechtschreibung und Grammatik.")
    temperature = int(os.environ.get("temperature", "0")) / 10
    api_key = os.environ.get("mistral_api_key", "")
    model = os.environ.get("mistral_model", "mistral-large-latest")

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": text},
        ],
        "temperature": temperature,
    }

    req = urllib.request.Request(
        "https://api.mistral.ai/v1/chat/completions",
        data=json.dumps(payload).encode(),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )

    with urllib.request.urlopen(req, timeout=60) as resp:
        data = json.loads(resp.read())

    return data["choices"][0]["message"]["content"].strip()


def correct_languagetool(text):
    username = os.environ.get("lt_username", "")
    api_key = os.environ.get("lt_api_key", "")

    params = urllib.parse.urlencode({
        "text": text,
        "language": "de-DE",
        "username": username,
        "apiKey": api_key,
    }).encode()

    req = urllib.request.Request(
        "https://api.languagetoolplus.com/v2/check",
        data=params,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )

    with urllib.request.urlopen(req, timeout=60) as resp:
        data = json.loads(resp.read())

    matches = data.get("matches", [])
    if not matches:
        return text

    matches.sort(key=lambda m: m["offset"], reverse=True)

    result = text
    for match in matches:
        offset = match["offset"]
        length = match["length"]
        replacements = match.get("replacements", [])
        if replacements:
            replacement = replacements[0]["value"]
            result = result[:offset] + replacement + result[offset + length:]

    result = result.replace("\u00a0", " ")
    return result


if __name__ == "__main__":
    main()
