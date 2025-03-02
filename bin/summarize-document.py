import sys
import requests
import json
import pdfplumber
import os

ollama_server = "localhost:11434"

def suck_document(document):
    file_extension = os.path.splitext(document)[1].lower()
    if file_extension == ".pdf":
        content = ""
        with pdfplumber.open(document) as pdf:
            for page in pdf.pages:
                content += page.extract_text() + "\n"
        content.strip()
    else:
        with open(document, "r", encoding="utf-8") as file:
            content = file.read()
    return(content)

def send_to_ollama(document, input_string):
    """Sends the input_string to the Ollama server and prints the response."""
    url = f"http://{ollama_server}/api/generate"  # Adjust this if your API endpoint differs
    payload = {
        "model": "DeepSeek-R1",  # Adjust model name if needed
        "prompt": input_string + suck_document(document),
        "stream": False
    }
    headers = {"Content-Type": "application/json"}

    try:
        response = requests.post(url, data=json.dumps(payload), headers=headers)
        response.raise_for_status()
        data = response.json()
        print(data.get("response", "No response from server."))
    except requests.exceptions.RequestException as e:
        print(f"Error communicating with Ollama server: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python summarize-document.py document summarize-prompt")
        sys.exit(1)

    document = sys.argv[1]
    summarize_prompt = "".join(sys.argv[2:]) + ": "
    send_to_ollama(document, summarize_prompt)
