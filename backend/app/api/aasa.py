import os
import json
from fastapi import APIRouter, Response

router = APIRouter()

APPLE_TEAM_ID = os.getenv("APPLE_TEAM_ID", "YOURTEAMID").strip()
IOS_BUNDLE_ID = os.getenv("IOS_BUNDLE_ID", "io.repduel.app").strip()


def _resp() -> Response:
  body = json.dumps({
    "applinks": {
      "apps": [],
      "details": [
        {"appID": f"{APPLE_TEAM_ID}.{IOS_BUNDLE_ID}", "paths": ["*"]}
      ]
    }
  })
  return Response(body, media_type="application/json")


@router.get("/.well-known/apple-app-site-association")
def aasa_wk():
  return _resp()


@router.get("/apple-app-site-association")
def aasa_root():
  return _resp()

