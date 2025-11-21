#!/usr/bin/env python3

"""
summarize-document.py - Summarize documents using Ollama LLM

This script extracts text from documents (PDF or text files) and sends them
to an Ollama server for summarization or analysis.

Usage: summarize-document.py [-s server] [-m model] document prompt
  -s SERVER  Ollama server address (default: localhost:11434)
  -m MODEL   Model to use (default: DeepSeek-R1)
  -h         Show this help

Example:
  summarize-document.py paper.pdf "Summarize this paper"
  summarize-document.py -m llama2 notes.txt "Extract key points"
"""

import sys
import os
import json
import argparse
from pathlib import Path
from typing import Optional

try:
    import requests
except ImportError:
    print("Error: requests library not found. Install with: pip install requests", file=sys.stderr)
    sys.exit(1)

try:
    import pdfplumber
    HAS_PDF_SUPPORT = True
except ImportError:
    HAS_PDF_SUPPORT = False


class DocumentSummarizer:
    """Handles document summarization using Ollama."""
    
    def __init__(self, server: str = "localhost:11434", model: str = "DeepSeek-R1"):
        """Initialize the summarizer.
        
        Args:
            server: Ollama server address
            model: Model name to use
        """
        self.server = server
        self.model = model
        self.url = f"http://{server}/api/generate"
    
    def extract_text(self, document_path: str) -> str:
        """Extract text from a document.
        
        Args:
            document_path: Path to the document
            
        Returns:
            Extracted text content
            
        Raises:
            FileNotFoundError: If document doesn't exist
            ValueError: If document type is not supported
            RuntimeError: If extraction fails
        """
        path = Path(document_path)
        
        if not path.exists():
            raise FileNotFoundError(f"Document not found: {document_path}")
        
        if not path.is_file():
            raise ValueError(f"Not a file: {document_path}")
        
        file_extension = path.suffix.lower()
        
        # Handle PDF files
        if file_extension == ".pdf":
            if not HAS_PDF_SUPPORT:
                raise RuntimeError(
                    "PDF support not available. Install with: pip install pdfplumber"
                )
            
            try:
                content = []
                with pdfplumber.open(document_path) as pdf:
                    for i, page in enumerate(pdf.pages):
                        text = page.extract_text()
                        if text:
                            content.append(text)
                        else:
                            print(f"Warning: Page {i+1} appears to be empty", file=sys.stderr)
                
                if not content:
                    raise RuntimeError("No text could be extracted from PDF")
                
                return "\n".join(content)
                
            except Exception as e:
                raise RuntimeError(f"Failed to extract PDF content: {e}")
        
        # Handle text files
        elif file_extension in (".txt", ".md", ".rst", ".log", ".csv", ".json", ".xml", ".html", ""):
            try:
                with open(document_path, "r", encoding="utf-8") as f:
                    content = f.read()
                
                if not content.strip():
                    raise RuntimeError("Document is empty")
                
                return content
                
            except UnicodeDecodeError:
                raise RuntimeError("File is not a valid text file (encoding error)")
            except Exception as e:
                raise RuntimeError(f"Failed to read file: {e}")
        
        else:
            raise ValueError(
                f"Unsupported file type: {file_extension}. "
                f"Supported types: .pdf, .txt, .md, .rst, .log, .csv, .json, .xml, .html"
            )
    
    def summarize(self, document_path: str, prompt: str) -> str:
        """Summarize a document using Ollama.
        
        Args:
            document_path: Path to the document
            prompt: Prompt for the LLM
            
        Returns:
            Generated response
            
        Raises:
            RuntimeError: If API request fails
        """
        # Extract document content
        try:
            content = self.extract_text(document_path)
        except Exception as e:
            raise RuntimeError(f"Failed to extract document: {e}")
        
        # Prepare payload
        full_prompt = f"{prompt}\n\n{content}"
        payload = {
            "model": self.model,
            "prompt": full_prompt,
            "stream": False
        }
        
        # Send request to Ollama
        try:
            print(f"Sending request to {self.url}...", file=sys.stderr)
            print(f"Using model: {self.model}", file=sys.stderr)
            print(f"Document size: {len(content)} characters", file=sys.stderr)
            
            response = requests.post(
                self.url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=300  # 5 minute timeout
            )
            response.raise_for_status()
            
            data = response.json()
            
            if "response" not in data:
                raise RuntimeError("Invalid response from server (missing 'response' field)")
            
            return data["response"]
            
        except requests.exceptions.Timeout:
            raise RuntimeError("Request timed out after 5 minutes")
        except requests.exceptions.ConnectionError:
            raise RuntimeError(f"Cannot connect to Ollama server at {self.server}")
        except requests.exceptions.HTTPError as e:
            raise RuntimeError(f"HTTP error: {e}")
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"Request failed: {e}")
        except json.JSONDecodeError:
            raise RuntimeError("Invalid JSON response from server")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Summarize documents using Ollama LLM",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s paper.pdf "Summarize this paper"
  %(prog)s -m llama2 notes.txt "Extract key points"
  %(prog)s -s myserver:11434 document.pdf "Analyze this document"

Supported file types:
  - PDF (.pdf) - requires pdfplumber
  - Text files (.txt, .md, .rst, .log, .csv, .json, .xml, .html)
        """
    )
    
    parser.add_argument(
        "document",
        help="Path to document to summarize"
    )
    
    parser.add_argument(
        "prompt",
        nargs="+",
        help="Prompt for the LLM"
    )
    
    parser.add_argument(
        "-s", "--server",
        default="localhost:11434",
        help="Ollama server address (default: localhost:11434)"
    )
    
    parser.add_argument(
        "-m", "--model",
        default="DeepSeek-R1",
        help="Model to use (default: DeepSeek-R1)"
    )
    
    args = parser.parse_args()
    
    # Combine prompt parts
    prompt = " ".join(args.prompt)
    
    # Create summarizer
    summarizer = DocumentSummarizer(server=args.server, model=args.model)
    
    # Perform summarization
    try:
        result = summarizer.summarize(args.document, prompt)
        print(result)
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
