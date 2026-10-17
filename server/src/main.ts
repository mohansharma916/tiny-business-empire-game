// Nakama entry point. Nakama calls InitModule once at server start.
// Keep this file last in tsconfig.json "files" so every helper is defined before it runs.

function InitModule(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, initializer: nkruntime.Initializer) {
  setupGlobalLeaderboards(nk, logger);

  initializer.registerRpc("set_country", rpcSetCountry);
  initializer.registerRpc("register_push_token", rpcRegisterPushToken);
  initializer.registerRpc("submit_score", rpcSubmitScore);
  initializer.registerRpc("get_my_ranks", rpcGetMyRanks);
  initializer.registerRpc("delete_my_account", rpcDeleteMyAccount);

  logger.info("Tiny Business Empire server module loaded");
}

// Nakama looks up InitModule by name; this line stops the compiler from removing it.
!InitModule && InitModule.bind(null);
