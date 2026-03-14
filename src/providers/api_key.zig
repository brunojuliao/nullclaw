const std = @import("std");
const builtin = @import("builtin");
const config_mod = @import("../config_types.zig");
const platform = @import("../platform.zig");
const provider_names = @import("../provider_names.zig");

pub const QwenCliCredentials = struct {
    access_token: []u8,
};

/// Resolve API key for a provider from config and environment variables.
///
/// Resolution order:
/// 1. Explicitly provided `api_key` parameter (trimmed, filtered if empty)
/// 2. For `qwen-portal` only: `QWEN_OAUTH_TOKEN`, then `~/.qwen/oauth_creds.json`
/// 3. Provider-specific environment variable
/// 4. Generic fallback variables (`NULLCLAW_API_KEY`, `API_KEY`)
pub fn resolveApiKey(
    allocator: std.mem.Allocator,
    provider_name: []const u8,
    api_key: ?[]const u8,
) !?[]u8 {
    // 1. Explicit key
    if (api_key) |key| {
        const trimmed = std.mem.trim(u8, key, " \t\r\n");
        if (trimmed.len > 0) {
            return try allocator.dupe(u8, trimmed);
        }
    }

    // 2. Qwen OAuth env/file resolution for the qwen-portal provider only.
    if (std.ascii.eqlIgnoreCase(provider_name, "qwen-portal")) {
        if (loadNonEmptyEnv(allocator, "QWEN_OAUTH_TOKEN")) |value| {
            return value;
        }
        if (tryLoadQwenCliToken(allocator)) |creds| {
            return creds.access_token;
        }
    }

    // 3. Provider-specific env vars
    const env_candidates = providerEnvCandidates(provider_name);
    for (env_candidates) |env_var| {
        if (env_var.len == 0) break;
        if (loadNonEmptyEnv(allocator, env_var)) |value| {
            return value;
        }
    }

    // 4. Generic fallbacks
    const fallbacks = [_][]const u8{ "NULLCLAW_API_KEY", "API_KEY" };
    for (fallbacks) |env_var| {
        if (loadNonEmptyEnv(allocator, env_var)) |value| {
            return value;
        }
    }

    return null;
}

fn loadNonEmptyEnv(allocator: std.mem.Allocator, name: []const u8) ?[]u8 {
    if (std.process.getEnvVarOwned(allocator, name)) |value| {
        defer allocator.free(value);
        const trimmed = std.mem.trim(u8, value, " \t\r\n");
        if (trimmed.len > 0) {
            return allocator.dupe(u8, trimmed) catch null;
        }
        return null;
    } else |_| {
        return null;
    }
}

pub fn parseQwenCredentialsJson(allocator: std.mem.Allocator, json_bytes: []const u8) ?QwenCliCredentials {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_bytes, .{}) catch return null;
    defer parsed.deinit();

    const root_obj = switch (parsed.value) {
        .object => |obj| obj,
        else => return null,
    };

    const access_token_val = root_obj.get("access_token") orelse return null;
    const access_token = switch (access_token_val) {
        .string => |value| value,
        else => return null,
    };
    const trimmed = std.mem.trim(u8, access_token, " \t\r\n");
    if (trimmed.len == 0) return null;

    return .{
        .access_token = allocator.dupe(u8, trimmed) catch return null,
    };
}

pub fn tryLoadQwenCliToken(allocator: std.mem.Allocator) ?QwenCliCredentials {
    if (builtin.is_test) return null;

    const home = platform.getHomeDir(allocator) catch return null;
    defer allocator.free(home);

    const path = std.fs.path.join(allocator, &.{ home, ".qwen", "oauth_creds.json" }) catch return null;
    defer allocator.free(path);

    const file = std.fs.cwd().openFile(path, .{}) catch return null;
    defer file.close();

    const json_bytes = file.readToEndAlloc(allocator, 1024 * 1024) catch return null;
    defer allocator.free(json_bytes);

    return parseQwenCredentialsJson(allocator, json_bytes);
}

fn providerEnvCandidates(name: []const u8) [3][]const u8 {
    const canonical = provider_names.canonicalProviderNameIgnoreCase(name);
    const map = std.StaticStringMap([3][]const u8).initComptime(.{
        .{ "anthropic", .{ "ANTHROPIC_OAUTH_TOKEN", "ANTHROPIC_API_KEY", "" } },
        .{ "openrouter", .{ "OPENROUTER_API_KEY", "", "" } },
        .{ "openai", .{ "OPENAI_API_KEY", "", "" } },
        .{ "azure", .{ "AZURE_OPENAI_API_KEY", "", "" } },
        .{ "gemini", .{ "GEMINI_API_KEY", "GOOGLE_API_KEY", "" } },
        .{ "vertex", .{ "VERTEX_API_KEY", "VERTEX_OAUTH_TOKEN", "GOOGLE_OAUTH_ACCESS_TOKEN" } },
        .{ "groq", .{ "GROQ_API_KEY", "", "" } },
        .{ "mistral", .{ "MISTRAL_API_KEY", "", "" } },
        .{ "deepseek", .{ "DEEPSEEK_API_KEY", "", "" } },
        .{ "z.ai", .{ "ZAI_API_KEY", "", "" } },
        .{ "zai", .{ "ZAI_API_KEY", "", "" } },
        .{ "glm", .{ "ZHIPU_API_KEY", "", "" } },
        .{ "zhipu", .{ "ZHIPU_API_KEY", "", "" } },
        .{ "xai", .{ "XAI_API_KEY", "", "" } },
        .{ "grok", .{ "XAI_API_KEY", "", "" } },
        .{ "together", .{ "TOGETHER_API_KEY", "", "" } },
        .{ "together-ai", .{ "TOGETHER_API_KEY", "", "" } },
        .{ "fireworks", .{ "FIREWORKS_API_KEY", "", "" } },
        .{ "fireworks-ai", .{ "FIREWORKS_API_KEY", "", "" } },
        .{ "synthetic", .{ "SYNTHETIC_API_KEY", "", "" } },
        .{ "opencode", .{ "OPENCODE_API_KEY", "", "" } },
        .{ "opencode-zen", .{ "OPENCODE_API_KEY", "", "" } },
        .{ "minimax", .{ "MINIMAX_API_KEY", "", "" } },
        .{ "qwen", .{ "DASHSCOPE_API_KEY", "", "" } },
        .{ "dashscope", .{ "DASHSCOPE_API_KEY", "", "" } },
        .{ "qwen-portal", .{ "QWEN_OAUTH_TOKEN", "", "" } },
        .{ "qianfan", .{ "QIANFAN_ACCESS_KEY", "", "" } },
        .{ "baidu", .{ "QIANFAN_ACCESS_KEY", "", "" } },
        .{ "perplexity", .{ "PERPLEXITY_API_KEY", "", "" } },
        .{ "cohere", .{ "COHERE_API_KEY", "", "" } },
        .{ "venice", .{ "VENICE_API_KEY", "", "" } },
        .{ "poe", .{ "POE_API_KEY", "", "" } },
        .{ "moonshot", .{ "MOONSHOT_API_KEY", "", "" } },
        .{ "kimi", .{ "MOONSHOT_API_KEY", "", "" } },
        .{ "bedrock", .{ "AWS_ACCESS_KEY_ID", "", "" } },
        .{ "aws-bedrock", .{ "AWS_ACCESS_KEY_ID", "", "" } },
        .{ "cloudflare", .{ "CLOUDFLARE_API_TOKEN", "", "" } },
        .{ "cloudflare-ai", .{ "CLOUDFLARE_API_TOKEN", "", "" } },
        .{ "vercel-ai", .{ "VERCEL_API_KEY", "", "" } },
        .{ "vercel", .{ "VERCEL_API_KEY", "", "" } },
        .{ "copilot", .{ "GITHUB_TOKEN", "", "" } },
        .{ "github-copilot", .{ "GITHUB_TOKEN", "", "" } },
        .{ "nvidia", .{ "NVIDIA_API_KEY", "", "" } },
        .{ "nvidia-nim", .{ "NVIDIA_API_KEY", "", "" } },
        .{ "build.nvidia.com", .{ "NVIDIA_API_KEY", "", "" } },
        .{ "astrai", .{ "ASTRAI_API_KEY", "", "" } },
        .{ "ollama", .{ "API_KEY", "", "" } },
        .{ "lmstudio", .{ "API_KEY", "", "" } },
        .{ "lm-studio", .{ "API_KEY", "", "" } },
        .{ "claude-cli", .{ "ANTHROPIC_API_KEY", "", "" } },
        .{ "codex-cli", .{ "OPENAI_API_KEY", "", "" } },
    });
    return map.get(canonical) orelse .{ "", "", "" };
}

/// Resolve API key with config providers as first priority, then env vars:
///   1. providers[].api_key from config
///   2. Provider-specific env var (GROQ_API_KEY, etc.)
///   3. Generic fallbacks (NULLCLAW_API_KEY, API_KEY)
pub fn resolveApiKeyFromConfig(
    allocator: std.mem.Allocator,
    provider_name: []const u8,
    providers: []const config_mod.ProviderEntry,
) !?[]u8 {
    for (providers) |e| {
        if (provider_names.providerNamesMatch(e.name, provider_name)) {
            if (e.api_key) |k| return try allocator.dupe(u8, k);
        }
    }
    return resolveApiKey(allocator, provider_name, null);
}

// ════════════════════════════════════════════════════════════════════════════
// Tests
// ════════════════════════════════════════════════════════════════════════════

test "NVIDIA_API_KEY env resolves nvidia credential" {
    const allocator = std.testing.allocator;
    // providerEnvCandidates returns NVIDIA_API_KEY for nvidia
    const candidates = providerEnvCandidates("nvidia");
    try std.testing.expectEqualStrings("NVIDIA_API_KEY", candidates[0]);
    // Also check aliases
    const candidates_nim = providerEnvCandidates("nvidia-nim");
    try std.testing.expectEqualStrings("NVIDIA_API_KEY", candidates_nim[0]);
    const candidates_build = providerEnvCandidates("build.nvidia.com");
    try std.testing.expectEqualStrings("NVIDIA_API_KEY", candidates_build[0]);
    _ = allocator;
}

test "astrai env candidate is ASTRAI_API_KEY" {
    const candidates = providerEnvCandidates("astrai");
    try std.testing.expectEqualStrings("ASTRAI_API_KEY", candidates[0]);
}

test "vertex env candidate is VERTEX_API_KEY" {
    const candidates = providerEnvCandidates("vertex");
    try std.testing.expectEqualStrings("VERTEX_API_KEY", candidates[0]);
}

test "qwen uses dashscope api key env candidate" {
    const candidates = providerEnvCandidates("qwen");
    try std.testing.expectEqualStrings("DASHSCOPE_API_KEY", candidates[0]);
}

test "qwen-portal env candidate uses oauth token" {
    const candidates = providerEnvCandidates("qwen-portal");
    try std.testing.expectEqualStrings("QWEN_OAUTH_TOKEN", candidates[0]);
}

test "azure aliases share Azure env candidate" {
    try std.testing.expectEqualStrings("AZURE_OPENAI_API_KEY", providerEnvCandidates("azure")[0]);
    try std.testing.expectEqualStrings("AZURE_OPENAI_API_KEY", providerEnvCandidates("azure-openai")[0]);
    try std.testing.expectEqualStrings("AZURE_OPENAI_API_KEY", providerEnvCandidates("azure_openai")[0]);
}

test "providerEnvCandidates includes onboarding env hints" {
    const onboard = @import("../onboard.zig");

    for (onboard.known_providers) |provider| {
        if (provider.env_var.len == 0) continue;
        const candidates = providerEnvCandidates(provider.key);

        var matched = false;
        for (candidates) |candidate| {
            if (candidate.len == 0) break;
            if (std.mem.eql(u8, candidate, provider.env_var)) {
                matched = true;
                break;
            }
        }

        try std.testing.expect(matched);
    }
}

test "resolveApiKeyFromConfig finds key from providers" {
    const entries = [_]config_mod.ProviderEntry{
        .{ .name = "openrouter", .api_key = "sk-or-test" },
        .{ .name = "groq", .api_key = "gsk_test" },
    };
    const result = try resolveApiKeyFromConfig(std.testing.allocator, "groq", &entries);
    defer if (result) |r| std.testing.allocator.free(r);
    try std.testing.expectEqualStrings("gsk_test", result.?);
}

test "resolveApiKeyFromConfig matches provider aliases" {
    const entries = [_]config_mod.ProviderEntry{
        .{ .name = "azure", .api_key = "azure-test" },
    };
    const result = try resolveApiKeyFromConfig(std.testing.allocator, "azure-openai", &entries);
    defer if (result) |r| std.testing.allocator.free(r);
    try std.testing.expectEqualStrings("azure-test", result.?);
}

test "resolveApiKeyFromConfig falls through to env for missing provider" {
    const entries = [_]config_mod.ProviderEntry{
        .{ .name = "openrouter", .api_key = "sk-or-test" },
    };
    // Falls through to env-based resolution (may or may not find a key)
    const result = try resolveApiKeyFromConfig(std.testing.allocator, "nonexistent", &entries);
    if (result) |r| std.testing.allocator.free(r);
}

test "parseQwenCredentialsJson parses access token" {
    const creds = parseQwenCredentialsJson(std.testing.allocator, "{\"access_token\":\"test-token\"}").?;
    defer std.testing.allocator.free(creds.access_token);
    try std.testing.expectEqualStrings("test-token", creds.access_token);
}

test "parseQwenCredentialsJson rejects missing access token" {
    try std.testing.expect(parseQwenCredentialsJson(std.testing.allocator, "{\"refresh_token\":\"x\"}") == null);
}

test "parseQwenCredentialsJson rejects empty access token" {
    try std.testing.expect(parseQwenCredentialsJson(std.testing.allocator, "{\"access_token\":\"  \"}") == null);
}

test "parseQwenCredentialsJson rejects invalid json" {
    try std.testing.expect(parseQwenCredentialsJson(std.testing.allocator, "{") == null);
}

test "tryLoadQwenCliToken disabled during tests" {
    try std.testing.expect(tryLoadQwenCliToken(std.testing.allocator) == null);
}

test "resolveApiKey qwen-portal prefers oauth env over dashscope key" {
    if (comptime builtin.os.tag == .windows) return error.SkipZigTest;
    const c = @cImport({
        @cInclude("stdlib.h");
    });

    const oauth_key_z = try std.testing.allocator.dupeZ(u8, "QWEN_OAUTH_TOKEN");
    defer std.testing.allocator.free(oauth_key_z);
    const oauth_value_z = try std.testing.allocator.dupeZ(u8, "oauth-token");
    defer std.testing.allocator.free(oauth_value_z);
    try std.testing.expectEqual(@as(c_int, 0), c.setenv(oauth_key_z.ptr, oauth_value_z.ptr, 1));
    defer _ = c.unsetenv(oauth_key_z.ptr);

    const api_key_z = try std.testing.allocator.dupeZ(u8, "DASHSCOPE_API_KEY");
    defer std.testing.allocator.free(api_key_z);
    const api_value_z = try std.testing.allocator.dupeZ(u8, "dashscope-key");
    defer std.testing.allocator.free(api_value_z);
    try std.testing.expectEqual(@as(c_int, 0), c.setenv(api_key_z.ptr, api_value_z.ptr, 1));
    defer _ = c.unsetenv(api_key_z.ptr);

    const result = try resolveApiKey(std.testing.allocator, "qwen-portal", null);
    defer if (result) |value| std.testing.allocator.free(value);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("oauth-token", result.?);
}
