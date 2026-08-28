from __future__ import annotations

import argparse
import asyncio
import getpass
import os
import sys
from pathlib import Path


DEFAULT_SESSION_PATH = (
    Path.home() / ".config" / "hamsafar" / "telegram_user.session"
)


def _credentials() -> tuple[int, str]:
    try:
        api_id = int(input("Telegram App api_id: ").strip())
    except ValueError as error:
        raise RuntimeError("api_id must be an integer") from error
    api_hash = getpass.getpass("Telegram App api_hash (hidden): ").strip()
    if not api_hash:
        raise RuntimeError("api_hash is required")
    return api_id, api_hash


def _read_session(path: Path) -> str:
    try:
        session = path.read_text(encoding="utf-8").strip()
    except FileNotFoundError as error:
        raise RuntimeError(
            f"Session not found at {path}. Run the create command first."
        ) from error
    if not session:
        raise RuntimeError(f"Session file is empty: {path}")
    return session


async def _create(path: Path) -> None:
    try:
        from telethon import TelegramClient
        from telethon.sessions import StringSession
    except ImportError as error:
        raise RuntimeError(
            "Telethon is not installed. Run: "
            "python3 -m pip install -r telegram_collector/requirements.txt"
        ) from error

    api_id, api_hash = _credentials()
    phone = input("Telegram phone in international format: ").strip()
    if not phone:
        raise RuntimeError("Phone number is required")
    client = TelegramClient(StringSession(), api_id, api_hash)
    await client.start(
        phone=phone,
        code_callback=lambda: getpass.getpass("Telegram login code (hidden): "),
        password=lambda: getpass.getpass("Telegram 2FA password (hidden): "),
    )
    try:
        me = await client.get_me()
        session = client.session.save()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(session, encoding="utf-8")
        os.chmod(path, 0o600)
        print(f"Authorized Telegram user ID: {me.id}")
        print(f"Session saved with mode 600: {path}")
        print("Do not print or send this file. It grants access to the account.")
    finally:
        await client.disconnect()


async def _list_dialogs(path: Path) -> None:
    try:
        from telethon import TelegramClient
        from telethon.sessions import StringSession
    except ImportError as error:
        raise RuntimeError(
            "Telethon is not installed. Run: "
            "python3 -m pip install -r telegram_collector/requirements.txt"
        ) from error

    api_id, api_hash = _credentials()
    client = TelegramClient(StringSession(_read_session(path)), api_id, api_hash)
    await client.connect()
    try:
        if not await client.is_user_authorized():
            raise RuntimeError("Stored Telegram session is not authorized")
        print("\nChat ID\tTitle")
        async for dialog in client.iter_dialogs():
            if dialog.is_group or dialog.is_channel:
                print(f"{dialog.id}\t{dialog.name}")
    finally:
        await client.disconnect()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a private Telegram StringSession or list chat IDs."
    )
    parser.add_argument("command", choices=("create", "list"))
    parser.add_argument(
        "--session-file", type=Path, default=DEFAULT_SESSION_PATH
    )
    args = parser.parse_args()
    try:
        if args.command == "create":
            asyncio.run(_create(args.session_file.expanduser()))
        else:
            asyncio.run(_list_dialogs(args.session_file.expanduser()))
    except (KeyboardInterrupt, EOFError):
        print("Cancelled.", file=sys.stderr)
        return 130
    except Exception as error:
        print(f"Error: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
