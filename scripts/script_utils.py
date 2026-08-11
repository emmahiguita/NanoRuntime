"""
Shared utilities for NanoAI benchmark and research scripts.

Consolidates helpers that were previously duplicated across
android_stress_test.py, stress_test.py, and eval_harness.py
(DRY principle). Also adds prompt-injection sanitization.
"""

import re

# Special tokens used by Qwen-2.5 chat template.
# These must NOT appear in user input — if they do, the model
# may interpret them as template boundaries and the attacker
# can inject fake system/assistant messages (prompt injection).
_CHAT_SPECIAL_TOKENS = [
    "<|im_start|>",
    "<|im_end|>",
    "<|endoftext|>",
]


def sanitize_chat_input(text: str) -> str:
    """
    Strip chat-template special tokens from user input to prevent
    prompt injection. An attacker could embed <|im_start|>assistant
    tokens in their message to fake an assistant response.

    The tokens are removed (not escaped) because they have no
    legitimate use in user-provided chat text.
    """
    for token in _CHAT_SPECIAL_TOKENS:
        text = text.replace(token, "")
    return text


def format_chat_prompt(user_message: str, system: str = "") -> str:
    """
    Format a user message into the Qwen-2.5 chat template.

    Without this format, the model produces degenerate outputs
    (e.g., always responding with a single character).

    The user input is sanitized to strip chat-template special
    tokens before templating, preventing prompt injection.

    Ref: https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct
    """
    safe_user = sanitize_chat_input(user_message)
    parts = []
    if system:
        safe_system = sanitize_chat_input(system)
        parts.append(f"<|im_start|>system\n{safe_system}<|im_end|>\n")
    parts.append(f"<|im_start|>user\n{safe_user}<|im_end|>\n")
    parts.append("<|im_start|>assistant\n")
    return "".join(parts)
