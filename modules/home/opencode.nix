{
  delib,
  pkgs,
  ...
}:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
delib.module {
  name = "opencode";

  options = delib.singleEnableOption isDarwin;

  home.ifEnabled = {
    programs.opencode = {
      enable = true;
      settings = {
        model = "ollama/qwen3.5:9b-q4_K_M";
        enabled_providers = [
          "workers-ai"
          "opencode"
          "openrouter"
        ];
        disabled_providers = [ ];
        provider = {
          ollama = {
            npm = "@ai-sdk/openai-compatible";
            name = "Ollama (local)";
            options.baseURL = "http://127.0.0.1:11434/v1";
            models."qwen3.5:9b-q4_K_M" = {
              name = "Qwen3.5 9B Q4_K_M (local)";
              attachment = true;
              reasoning = true;
              tool_call = true;
              options.reasoningEffort = "none";
              limit = {
                context = 32768;
                output = 8192;
              };
              modalities = {
                input = [
                  "text"
                  "image"
                ];
                output = [ "text" ];
              };
            };
          };
          opencode.models."x-preview-f-free" = {
            name = "Ox Alpha Free (Unlimited)";
            attachment = true;
            reasoning = true;
            temperature = true;
            tool_call = true;
            interleaved.field = "reasoning_content";
            cost = {
              input = 0;
              output = 0;
              cache_read = 0;
            };
            limit = {
              context = 1000000;
              output = 131072;
            };
            modalities = {
              input = [
                "text"
                "image"
                "video"
              ];
              output = [ "text" ];
            };
            variants = {
              low.reasoningEffort = "low";
              high.reasoningEffort = "high";
              max.reasoningEffort = "max";
            };
          };
          openrouter = {
            name = "OpenRouter";
            npm = "@openrouter/ai-sdk-provider";
            options.baseURL = "https://openrouter.ai/api/v1";
            models."stealth/ox-alpha" = {
              name = "Ox Alpha";
              family = "alpha";
              attachment = true;
              reasoning = true;
              temperature = true;
              tool_call = true;
              cost = {
                input = 0;
                output = 0;
              };
              limit = {
                context = 1048576;
                output = 131072;
              };
              modalities = {
                input = [
                  "text"
                  "image"
                  "video"
                ];
                output = [ "text" ];
              };
              variants = {
                low.reasoning.effort = "low";
                high.reasoning.effort = "high";
                max.reasoning.effort = "max";
              };
            };
          };
        };
      };
    };

    services.ollama = {
      enable = true;
      environmentVariables = {
        OLLAMA_CONTEXT_LENGTH = "32768";
        OLLAMA_KEEP_ALIVE = "30m";
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_NO_CLOUD = "1";
        OLLAMA_NUM_PARALLEL = "1";
      };
    };
  };
}
