// Push notifications through Firebase Cloud Messaging (HTTP v1 API).
// FCM delivers to Android directly and to iOS through APNs (upload your APNs key in Firebase).
//
// Required runtime env (set in nakama.yml under runtime.env, never committed):
//   FCM_PROJECT_ID      Firebase project id
//   FCM_CLIENT_EMAIL    service account email
//   FCM_PRIVATE_KEY     service account private key (PEM, with \n escaped)
// If any are missing, pushes are skipped and logged; the game keeps working.

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const FCM_TOKEN_CACHE_KEY = "tbe_fcm_access_token";

function fcmConfigured(ctx: nkruntime.Context): boolean {
  return !!(ctx.env["FCM_PROJECT_ID"] && ctx.env["FCM_CLIENT_EMAIL"] && ctx.env["FCM_PRIVATE_KEY"]);
}

function fcmAccessToken(ctx: nkruntime.Context, nk: nkruntime.Nakama): string {
  const cached = nk.localcacheGet(FCM_TOKEN_CACHE_KEY);
  if (cached) {
    return cached as string;
  }
  const now = Math.floor(Date.now() / 1000);
  const privateKey = ctx.env["FCM_PRIVATE_KEY"].replace(/\\n/g, "\n");
  const assertion = nk.jwtGenerate("RS256", privateKey, {
    iss: ctx.env["FCM_CLIENT_EMAIL"],
    scope: FCM_SCOPE,
    aud: GOOGLE_TOKEN_URL,
    iat: now,
    exp: now + 3600,
  });
  const body =
    "grant_type=" + encodeURIComponent("urn:ietf:params:oauth:grant-type:jwt-bearer") +
    "&assertion=" + encodeURIComponent(assertion);
  const res = nk.httpRequest(GOOGLE_TOKEN_URL, "post", { "Content-Type": "application/x-www-form-urlencoded" }, body, 5000);
  if (res.code !== 200) {
    throw new Error("FCM token request failed: " + res.code + " " + res.body);
  }
  const token = JSON.parse(res.body).access_token as string;
  // Google tokens last 1 hour; refresh a little early.
  nk.localcachePut(FCM_TOKEN_CACHE_KEY, token, 3300);
  return token;
}

// Returns true if sent. Never throws: a failed push must not fail score submission.
function sendPush(
  ctx: nkruntime.Context,
  logger: nkruntime.Logger,
  nk: nkruntime.Nakama,
  deviceToken: string,
  title: string,
  body: string,
  data: { [key: string]: string }
): boolean {
  if (!deviceToken) {
    return false;
  }
  if (!fcmConfigured(ctx)) {
    logger.warn("FCM not configured; skipping push");
    return false;
  }
  try {
    const accessToken = fcmAccessToken(ctx, nk);
    const url = "https://fcm.googleapis.com/v1/projects/" + ctx.env["FCM_PROJECT_ID"] + "/messages:send";
    const message = {
      message: {
        token: deviceToken,
        notification: { title: title, body: body },
        data: data,
        android: { priority: "normal" },
      },
    };
    const res = nk.httpRequest(
      url,
      "post",
      { "Content-Type": "application/json", Authorization: "Bearer " + accessToken },
      JSON.stringify(message),
      5000
    );
    if (res.code !== 200) {
      logger.warn("FCM send failed: %d %s", res.code, res.body);
      return false;
    }
    return true;
  } catch (err) {
    logger.error("FCM error: %s", String(err));
    return false;
  }
}
