# Vendor-Independent Agent Development Guide
## Universal Methodology for Building Production AI Agents

**Version:** 1.2.0
**Date:** 2026-01-25
**Last Updated:** 2026-02-06
**Language:** English (with Russian comments where helpful)
**Target Audience:** Developers building LLM agents with any provider
**Compatibility:** OpenAI, Anthropic, Google, Mistral, Cohere, Local LLMs

> **🆕 v1.1.1 Update:** Added note on System-Reminder Problem (GAP-ARCH-002). Claude Code CLI wraps claudeMd in `<system-reminder>may or may not be relevant</system-reminder>`. **Solution:** 3-tier priority override via `--append-system-prompt` (CORE_INSTRUCTIONS.md + claude-wrapper). **Documentation:** `docs/SYSTEM_REMINDER_BYPASS.md`

---

## Table of Contents

1. [Introduction & Provider Landscape](#1-introduction--provider-landscape)
2. [Architecture Fundamentals](#2-architecture-fundamentals)
3. [System Prompt Design](#3-system-prompt-design)
4. [Tool Integration Patterns](#4-tool-integration-patterns)
5. [Multi-Agent Orchestration](#5-multi-agent-orchestration)
6. [Evaluation & Quality Assurance](#6-evaluation--quality-assurance)
7. [Deployment & Operations](#7-deployment--operations)
8. [Provider-Specific Considerations](#8-provider-specific-considerations)
9. [Migration Strategies](#9-migration-strategies)
10. [Appendix: Quick Reference](#appendix-quick-reference)

---

## 1. Introduction & Provider Landscape

### 1.1 Why Vendor-Independence Matters

Building vendor-independent AI agents provides:

| Benefit | Description |
|---------|-------------|
| **Flexibility** | Switch providers based on cost, performance, or availability |
| **Risk Mitigation** | Avoid vendor lock-in, API deprecations, price changes |
| **Optimization** | Use different models for different tasks (routing) |
| **Compliance** | Meet data residency requirements with local models |
| **Cost Control** | Leverage competition between providers |

### 1.2 Provider Landscape (2026)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      LLM PROVIDER LANDSCAPE 2026                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  COMMERCIAL (Cloud API)                                                     │
│  ─────────────────────                                                      │
│  • Anthropic: Claude Opus 4.5, Sonnet 4.5, Haiku 3.7                       │
│  • OpenAI: GPT-5.2, GPT-4.5-turbo, o3-pro (reasoning)                      │
│  • Google: Gemini 3, Gemini 2.5 Flash (2M context)                         │
│  • Mistral: Large 2, Codestral, Ministral                                  │
│  • Cohere: Command R+, Embed v3                                             │
│  • xAI: Grok 4.1                                                            │
│                                                                             │
│  OPEN SOURCE (Self-hosted)                                                  │
│  ─────────────────────────                                                  │
│  • Meta: Llama 4 (405B, 70B, 8B)                                           │
│  • Mistral: Mistral Large 2 (open weights)                                 │
│  • Alibaba: Qwen 3 series                                                   │
│  • DeepSeek: DeepSeek V3.2, R1 (reasoning)                                 │
│  • 01.AI: Yi-1.5 series                                                     │
│                                                                             │
│  REGIONAL                                                                   │
│  ────────                                                                   │
│  • Russia: YandexGPT 5, GigaChat MAX                                       │
│  • China: Baidu ERNIE 5.0, ByteDance Doubao                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.3 Model Selection Matrix

| Use Case | Recommended Models | Rationale |
|----------|-------------------|-----------|
| **General Assistant** | Claude Sonnet, GPT-4.5 | Balance of quality/cost |
| **Complex Reasoning** | Claude Opus, o3-pro, DeepSeek R1 | Deep reasoning capability |
| **Code Generation** | Claude Sonnet, Codestral, DeepSeek Coder | Code-optimized |
| **Long Context** | Gemini 3 (2M), Claude (200k) | Extended context window |
| **Cost-Sensitive** | Haiku, GPT-4.5-mini, Llama 4 8B | Low cost per token |
| **Privacy/On-Premise** | Llama 4, Mistral, Qwen 3 | Self-hosted options |
| **Russian Language** | YandexGPT, GigaChat, Claude | Native Russian support |

---

## 2. Architecture Fundamentals

### 2.1 Universal Agent Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       UNIVERSAL AGENT ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         APPLICATION LAYER                            │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐               │   │
│  │  │   CLI   │  │   Web   │  │   API   │  │   IDE   │               │   │
│  │  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘               │   │
│  └───────┴────────────┴────────────┴────────────┴───────────────────────┘   │
│                                    │                                        │
│  ┌─────────────────────────────────▼───────────────────────────────────┐   │
│  │                       ORCHESTRATION LAYER                            │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│  │  │   Router     │  │  Supervisor  │  │   Memory     │              │   │
│  │  │ (model/task) │  │  (workflow)  │  │ (persistence)│              │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘              │   │
│  └─────────────────────────────────┬───────────────────────────────────┘   │
│                                    │                                        │
│  ┌─────────────────────────────────▼───────────────────────────────────┐   │
│  │                     PROVIDER ABSTRACTION LAYER                       │   │
│  │  ┌────────────────────────────────────────────────────────────┐    │   │
│  │  │  LiteLLM / OpenRouter / Custom Wrapper                      │    │   │
│  │  └────────────────────────────────────────────────────────────┘    │   │
│  │       │           │           │           │           │            │   │
│  │  ┌────▼────┐ ┌────▼────┐ ┌────▼────┐ ┌────▼────┐ ┌────▼────┐     │   │
│  │  │Anthropic│ │ OpenAI  │ │ Google  │ │ Mistral │ │  Local  │     │   │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│  ┌─────────────────────────────────▼───────────────────────────────────┐   │
│  │                          TOOL LAYER                                  │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐               │   │
│  │  │   MCP   │  │Function │  │  Code   │  │ Browser │               │   │
│  │  │ Servers │  │ Calling │  │  Exec   │  │  Use    │               │   │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Provider Abstraction Layer

**Key Principle:** All LLM calls go through an abstraction layer that normalizes provider differences.

#### Option A: LiteLLM (Recommended)

```python
# LiteLLM provides unified API for 100+ providers
from litellm import completion

# Same code works with any provider
response = completion(
    model="claude-3-5-sonnet-20241022",  # or "gpt-4", "gemini/gemini-pro"
    messages=[{"role": "user", "content": "Hello"}]
)

# Switching providers is a config change
response = completion(
    model="gpt-4-turbo",
    messages=[{"role": "user", "content": "Hello"}]
)
```

#### Option B: OpenRouter (API Gateway)

```python
import openai

client = openai.OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key="your-openrouter-key"
)

# Access any model through single API
response = client.chat.completions.create(
    model="anthropic/claude-3.5-sonnet",
    messages=[{"role": "user", "content": "Hello"}]
)
```

#### Option C: Custom Wrapper

```python
from abc import ABC, abstractmethod
from typing import List, Dict, Any

class LLMProvider(ABC):
    """Abstract base class for LLM providers"""

    @abstractmethod
    def complete(self, messages: List[Dict], **kwargs) -> str:
        pass

    @abstractmethod
    def complete_with_tools(self, messages: List[Dict], tools: List[Dict], **kwargs) -> Dict:
        pass

class AnthropicProvider(LLMProvider):
    def __init__(self, api_key: str, model: str = "claude-3-5-sonnet-20241022"):
        import anthropic
        self.client = anthropic.Anthropic(api_key=api_key)
        self.model = model

    def complete(self, messages: List[Dict], **kwargs) -> str:
        response = self.client.messages.create(
            model=self.model,
            messages=messages,
            **kwargs
        )
        return response.content[0].text

class OpenAIProvider(LLMProvider):
    def __init__(self, api_key: str, model: str = "gpt-4-turbo"):
        import openai
        self.client = openai.OpenAI(api_key=api_key)
        self.model = model

    def complete(self, messages: List[Dict], **kwargs) -> str:
        response = self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            **kwargs
        )
        return response.choices[0].message.content

# Factory pattern for provider selection
def get_provider(provider_name: str, **kwargs) -> LLMProvider:
    providers = {
        "anthropic": AnthropicProvider,
        "openai": OpenAIProvider,
        # Add more providers as needed
    }
    return providers[provider_name](**kwargs)
```

### 2.3 Configuration Management

```yaml
# config.yaml - Environment-based provider configuration
providers:
  default: anthropic

  anthropic:
    api_key: ${ANTHROPIC_API_KEY}
    models:
      default: claude-3-5-sonnet-20241022
      reasoning: claude-3-opus-20240229
      fast: claude-3-haiku-20240307

  openai:
    api_key: ${OPENAI_API_KEY}
    models:
      default: gpt-4-turbo
      reasoning: o1-preview
      fast: gpt-4o-mini

  local:
    base_url: http://localhost:11434/v1
    models:
      default: llama3:70b
      fast: llama3:8b

routing:
  # Route tasks to appropriate models
  code_review: anthropic.default
  complex_reasoning: anthropic.reasoning
  quick_answers: openai.fast
  sensitive_data: local.default
```

---

## 3. System Prompt Design

### 3.1 Modular Prompt Architecture

**Key Principle:** System prompts should be modular, cacheable, and provider-agnostic.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MODULAR PROMPT ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TIER 1: CORE IDENTITY (Static, Cacheable)                                 │
│  ─────────────────────────────────────────                                 │
│  • Agent persona and capabilities                                          │
│  • Operating principles and constraints                                     │
│  • Response format guidelines                                               │
│  • Size: 1-3K tokens | Cache TTL: 5 min                                    │
│                                                                             │
│  TIER 2: DOMAIN MODULES (Semi-static, Cacheable)                           │
│  ───────────────────────────────────────────────                           │
│  • Domain-specific knowledge (security, DevOps, etc.)                      │
│  • Specialized procedures and checklists                                   │
│  • Size: 2-5K tokens per module | Cache TTL: 5 min                         │
│                                                                             │
│  TIER 3: CONTEXT (Dynamic, Not Cached)                                     │
│  ─────────────────────────────────────                                     │
│  • Current task details                                                    │
│  • Conversation history                                                    │
│  • User preferences for session                                            │
│  • Size: Variable                                                          │
│                                                                             │
│  TIER 4: EXAMPLES (Semi-static, Cacheable)                                 │
│  ─────────────────────────────────────────                                 │
│  • Few-shot examples for quality                                           │
│  • Domain-specific demonstrations                                          │
│  • Size: 1-3K tokens | Cache TTL: 5 min                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Universal System Prompt Template

```markdown
# Agent Configuration

## Identity
You are [AGENT_NAME], a [ROLE_DESCRIPTION].

## Capabilities
- [Capability 1]
- [Capability 2]
- [Capability 3]

## Operating Principles
1. **Accuracy First** — Verify facts, state uncertainty when unsure
2. **Structured Thinking** — Break complex problems into steps
3. **Transparency** — Explain reasoning and decisions
4. **Safety** — Follow security best practices

## Response Format
- Use markdown for structured output
- Include code blocks with language tags
- Provide examples where helpful

## Constraints
- Never fabricate information or citations
- Ask clarifying questions when requirements are unclear
- Request confirmation before destructive operations

## Tools Available
[Tool descriptions automatically injected based on provider]
```

### 3.3 Provider-Specific Prompt Optimizations

| Provider | Optimization | Notes |
|----------|-------------|-------|
| **Anthropic** | Use XML tags for structure | `<context>`, `<instructions>`, `<output>` |
| **OpenAI** | Use clear sections with headers | GPT models respond well to hierarchical structure |
| **Google** | Include explicit examples | Gemini benefits from in-context examples |
| **Mistral** | Keep prompts concise | Smaller context window optimization |
| **Local** | Simplify instructions | Smaller models need clearer, shorter prompts |

### 3.4 Few-Shot Examples Library

```python
# examples_library.py - Provider-agnostic examples management

class ExamplesLibrary:
    """
    Manage few-shot examples across domains.
    Examples are provider-agnostic markdown files.
    """

    def __init__(self, examples_dir: str = "./examples"):
        self.examples_dir = Path(examples_dir)
        self.index = self._load_index()

    def get_examples(self, domain: str, task_type: str, count: int = 3) -> str:
        """
        Retrieve relevant examples for a domain and task.

        Args:
            domain: e.g., "security", "devops", "coding"
            task_type: e.g., "code_review", "debugging", "explanation"
            count: Number of examples to return

        Returns:
            Formatted examples string for prompt injection
        """
        examples = self._find_matching_examples(domain, task_type, count)
        return self._format_examples(examples)

    def _format_examples(self, examples: List[Dict]) -> str:
        """Format examples for prompt injection"""
        output = "## Examples\n\n"
        for i, ex in enumerate(examples, 1):
            output += f"### Example {i}: {ex['title']}\n\n"
            output += f"**Input:**\n{ex['input']}\n\n"
            output += f"**Output:**\n{ex['output']}\n\n"
            output += "---\n\n"
        return output

# Example file structure:
# examples/
# ├── security/
# │   ├── code_review_sql_injection.md
# │   ├── code_review_xss.md
# │   └── vulnerability_analysis.md
# ├── devops/
# │   ├── dockerfile_optimization.md
# │   ├── kubernetes_debugging.md
# │   └── terraform_review.md
# └── index.yaml
```

---

## 4. Tool Integration Patterns

### 4.1 Universal Tool Definition Format

**Key Principle:** Define tools in a provider-agnostic format, then convert to provider-specific schemas.

```python
# tools/base.py - Universal tool definition

from dataclasses import dataclass, field
from typing import List, Dict, Any, Callable
from enum import Enum

class ParameterType(Enum):
    STRING = "string"
    INTEGER = "integer"
    BOOLEAN = "boolean"
    ARRAY = "array"
    OBJECT = "object"

@dataclass
class ToolParameter:
    name: str
    type: ParameterType
    description: str
    required: bool = True
    default: Any = None
    enum: List[str] = None

@dataclass
class UniversalTool:
    """Provider-agnostic tool definition"""
    name: str
    description: str
    parameters: List[ToolParameter]
    handler: Callable

    def to_anthropic(self) -> Dict:
        """Convert to Anthropic tool format"""
        return {
            "name": self.name,
            "description": self.description,
            "input_schema": {
                "type": "object",
                "properties": {
                    p.name: {
                        "type": p.type.value,
                        "description": p.description,
                        **({"enum": p.enum} if p.enum else {}),
                        **({"default": p.default} if p.default else {})
                    }
                    for p in self.parameters
                },
                "required": [p.name for p in self.parameters if p.required]
            }
        }

    def to_openai(self) -> Dict:
        """Convert to OpenAI function calling format"""
        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": self.description,
                "parameters": {
                    "type": "object",
                    "properties": {
                        p.name: {
                            "type": p.type.value,
                            "description": p.description,
                            **({"enum": p.enum} if p.enum else {})
                        }
                        for p in self.parameters
                    },
                    "required": [p.name for p in self.parameters if p.required]
                }
            }
        }

    def to_google(self) -> Dict:
        """Convert to Google Gemini tool format"""
        return {
            "function_declarations": [{
                "name": self.name,
                "description": self.description,
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        p.name: {
                            "type": p.type.value.upper(),
                            "description": p.description
                        }
                        for p in self.parameters
                    },
                    "required": [p.name for p in self.parameters if p.required]
                }
            }]
        }

# Example tool definition
file_read_tool = UniversalTool(
    name="read_file",
    description="Read contents of a file from the filesystem",
    parameters=[
        ToolParameter(
            name="file_path",
            type=ParameterType.STRING,
            description="Absolute path to the file to read"
        ),
        ToolParameter(
            name="encoding",
            type=ParameterType.STRING,
            description="File encoding",
            required=False,
            default="utf-8"
        )
    ],
    handler=lambda file_path, encoding="utf-8": open(file_path, encoding=encoding).read()
)
```

### 4.2 MCP (Model Context Protocol) Integration

MCP provides standardized tool integration across providers.

```python
# tools/mcp_adapter.py - MCP integration

import json
from typing import Dict, Any

class MCPAdapter:
    """
    Adapter for MCP (Model Context Protocol) servers.
    MCP is now a Linux Foundation standard (2025).
    """

    def __init__(self, server_config: Dict[str, Any]):
        self.servers = {}
        for name, config in server_config.items():
            self.servers[name] = self._connect_server(config)

    def list_tools(self) -> List[UniversalTool]:
        """Get all available tools from MCP servers"""
        tools = []
        for server_name, server in self.servers.items():
            server_tools = server.list_tools()
            for tool in server_tools:
                tools.append(self._mcp_to_universal(tool, server_name))
        return tools

    def call_tool(self, tool_name: str, arguments: Dict) -> Any:
        """Execute a tool through MCP"""
        server_name, local_name = self._parse_tool_name(tool_name)
        return self.servers[server_name].call_tool(local_name, arguments)

    def _mcp_to_universal(self, mcp_tool: Dict, server_name: str) -> UniversalTool:
        """Convert MCP tool definition to universal format"""
        return UniversalTool(
            name=f"{server_name}_{mcp_tool['name']}",
            description=mcp_tool['description'],
            parameters=[
                ToolParameter(
                    name=p_name,
                    type=ParameterType(p_schema.get('type', 'string')),
                    description=p_schema.get('description', ''),
                    required=p_name in mcp_tool.get('inputSchema', {}).get('required', [])
                )
                for p_name, p_schema in mcp_tool.get('inputSchema', {}).get('properties', {}).items()
            ],
            handler=lambda **kwargs: self.call_tool(f"{server_name}_{mcp_tool['name']}", kwargs)
        )

# MCP Server configuration example
mcp_config = {
    "filesystem": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-filesystem", "/home/user"]
    },
    "github": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-github"],
        "env": {"GITHUB_TOKEN": "${GITHUB_TOKEN}"}
    }
}
```

### 4.3 Tool Call Patterns

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        TOOL CALL PATTERNS                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PATTERN 1: SINGLE TOOL CALL                                               │
│  ───────────────────────────                                               │
│  User → LLM → Tool Call → Tool Result → LLM → Response                    │
│  Use: Simple operations (file read, API call)                              │
│                                                                             │
│  PATTERN 2: AGENTIC LOOP (ReAct)                                           │
│  ──────────────────────────────                                            │
│  User → LLM → Thought → Action → Observation → ... → Response              │
│  Use: Complex tasks requiring multiple steps                               │
│                                                                             │
│  PATTERN 3: PARALLEL TOOL CALLS                                            │
│  ──────────────────────────────                                            │
│  User → LLM → [Tool 1, Tool 2, Tool 3] → Merge Results → Response         │
│  Use: Independent operations (fetch multiple files)                        │
│                                                                             │
│  PATTERN 4: NESTED TOOL CALLS                                              │
│  ───────────────────────────                                               │
│  User → LLM → Tool A → (internally calls Tool B) → Result → Response      │
│  Use: Composite operations (search then read)                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Multi-Agent Orchestration

### 5.1 Multi-Agent Patterns (2026)

| Pattern | Description | Best For | Frameworks |
|---------|-------------|----------|------------|
| **Supervisor** | Central agent delegates to specialists | Complex workflows | LangGraph, CrewAI |
| **Router** | Routes requests to best-suited agent | Mixed task types | Semantic Kernel |
| **Arbiter** | Multiple agents propose, one decides | High-stakes decisions | AWS Bedrock |
| **Swarm** | Agents collaborate dynamically | Open-ended exploration | OpenAI Swarm |
| **Pipeline** | Sequential handoffs between agents | Structured workflows | AutoGen |

### 5.2 Supervisor Pattern Implementation

```python
# orchestration/supervisor.py

from typing import List, Dict, Any
from dataclasses import dataclass

@dataclass
class AgentSpec:
    """Specification for a specialized agent"""
    name: str
    description: str
    capabilities: List[str]
    model: str  # Provider/model identifier
    system_prompt: str
    tools: List[str]

class Supervisor:
    """
    Supervisor agent that delegates to specialists.
    Provider-agnostic implementation.
    """

    def __init__(
        self,
        provider: LLMProvider,
        agents: List[AgentSpec],
        max_iterations: int = 10
    ):
        self.provider = provider
        self.agents = {a.name: a for a in agents}
        self.max_iterations = max_iterations

    def run(self, user_request: str) -> str:
        """
        Process user request through supervisor pattern.

        1. Supervisor analyzes request
        2. Delegates to appropriate specialist(s)
        3. Aggregates results
        4. Returns final response
        """
        # Step 1: Plan
        plan = self._create_plan(user_request)

        # Step 2: Execute
        results = []
        for step in plan['steps']:
            agent = self.agents[step['agent']]
            result = self._delegate_to_agent(agent, step['task'])
            results.append({
                'agent': step['agent'],
                'task': step['task'],
                'result': result
            })

        # Step 3: Synthesize
        return self._synthesize_results(user_request, results)

    def _create_plan(self, request: str) -> Dict:
        """Have supervisor create execution plan"""
        planning_prompt = f"""Analyze this request and create an execution plan.

Available Agents:
{self._format_agents()}

Request: {request}

Return a JSON plan with steps, each specifying which agent handles what task."""

        response = self.provider.complete([
            {"role": "user", "content": planning_prompt}
        ])
        return json.loads(response)

    def _delegate_to_agent(self, agent: AgentSpec, task: str) -> str:
        """Execute task with specialized agent"""
        # Could use different provider for each agent
        agent_provider = get_provider_for_model(agent.model)

        return agent_provider.complete([
            {"role": "system", "content": agent.system_prompt},
            {"role": "user", "content": task}
        ])

# Example usage
agents = [
    AgentSpec(
        name="code_reviewer",
        description="Reviews code for bugs, security issues, and best practices",
        capabilities=["code analysis", "security review", "style checking"],
        model="anthropic/claude-3-5-sonnet",
        system_prompt="You are an expert code reviewer...",
        tools=["read_file", "search_code"]
    ),
    AgentSpec(
        name="researcher",
        description="Researches technical topics and summarizes findings",
        capabilities=["web search", "documentation lookup", "summarization"],
        model="openai/gpt-4-turbo",
        system_prompt="You are a technical researcher...",
        tools=["web_search", "read_url"]
    )
]

supervisor = Supervisor(provider=get_provider("anthropic"), agents=agents)
result = supervisor.run("Review the authentication module and research best practices for OAuth 2.1")
```

### 5.3 A2A Protocol Integration (Google 2025)

```python
# orchestration/a2a.py - Agent-to-Agent Protocol support

"""
A2A Protocol enables interoperability between agents from different vendors.
Announced by Google in 2025 as complement to MCP.
"""

from dataclasses import dataclass
from typing import Optional

@dataclass
class A2ACapability:
    """Capability advertised via A2A"""
    name: str
    description: str
    input_schema: Dict
    output_schema: Dict

class A2AClient:
    """Client for A2A Protocol communication"""

    def __init__(self, agent_url: str):
        self.agent_url = agent_url
        self.capabilities = self._discover_capabilities()

    def _discover_capabilities(self) -> List[A2ACapability]:
        """Discover what the remote agent can do"""
        response = requests.get(f"{self.agent_url}/.well-known/a2a")
        return [A2ACapability(**cap) for cap in response.json()['capabilities']]

    def invoke(self, capability: str, input_data: Dict) -> Dict:
        """Invoke a capability on the remote agent"""
        response = requests.post(
            f"{self.agent_url}/invoke/{capability}",
            json=input_data,
            headers={"Content-Type": "application/json"}
        )
        return response.json()

# Example: Using external agent via A2A
external_agent = A2AClient("https://agent.example.com")
result = external_agent.invoke("summarize_document", {"url": "https://..."})
```

---

## 6. Evaluation & Quality Assurance

### 6.1 Evaluation Framework

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       EVALUATION FRAMEWORK                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  LAYER 1: UNIT METRICS                                                     │
│  ─────────────────────                                                     │
│  • Latency (p50, p95, p99)                                                 │
│  • Token usage (input, output, cached)                                     │
│  • Cost per request                                                        │
│  • Error rate                                                              │
│                                                                             │
│  LAYER 2: QUALITY METRICS                                                  │
│  ────────────────────────                                                  │
│  • Task completion rate                                                    │
│  • Accuracy (domain-specific)                                              │
│  • Factual consistency                                                     │
│  • Instruction following                                                   │
│                                                                             │
│  LAYER 3: AGENT METRICS                                                    │
│  ──────────────────────                                                    │
│  • Tool call success rate                                                  │
│  • Agentic loop efficiency (steps to completion)                           │
│  • Recovery from errors                                                    │
│  • Context utilization                                                     │
│                                                                             │
│  LAYER 4: BUSINESS METRICS                                                 │
│  ────────────────────────                                                  │
│  • User satisfaction (NPS, ratings)                                        │
│  • Task value delivered                                                    │
│  • Time saved vs manual                                                    │
│  • ROI                                                                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 LLM-as-a-Judge Pattern

```python
# evaluation/llm_judge.py

class LLMJudge:
    """
    Use an LLM to evaluate another LLM's output.
    Provider-agnostic implementation.
    """

    def __init__(self, judge_provider: LLMProvider):
        self.judge = judge_provider

    def evaluate(
        self,
        task: str,
        response: str,
        criteria: List[str],
        reference: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Evaluate a response against criteria.

        Args:
            task: Original task/question
            response: Response to evaluate
            criteria: List of evaluation criteria
            reference: Optional reference/gold answer

        Returns:
            Evaluation scores and reasoning
        """
        eval_prompt = f"""Evaluate the following response.

Task: {task}

Response to Evaluate:
{response}

{f"Reference Answer: {reference}" if reference else ""}

Evaluation Criteria:
{chr(10).join(f"- {c}" for c in criteria)}

For each criterion, provide:
1. Score (1-5)
2. Reasoning

Return as JSON with format:
{{
  "scores": {{"criterion": score, ...}},
  "reasoning": {{"criterion": "explanation", ...}},
  "overall_score": float,
  "summary": "brief overall assessment"
}}"""

        result = self.judge.complete([
            {"role": "user", "content": eval_prompt}
        ])
        return json.loads(result)

# Standard evaluation criteria
STANDARD_CRITERIA = [
    "Accuracy: Is the information factually correct?",
    "Completeness: Does the response fully address the task?",
    "Clarity: Is the response clear and well-organized?",
    "Relevance: Does the response stay on topic?",
    "Safety: Does the response avoid harmful content?"
]
```

### 6.3 Observability Stack

| Tool | License | Best For |
|------|---------|----------|
| **LangSmith** | Commercial | LangChain-based apps |
| **Langfuse** | MIT OSS | Independent, self-hosted |
| **Helicone** | OSS + SaaS | Quick setup, OpenAI-focused |
| **Phoenix** | OSS | OpenTelemetry-native |
| **OpenLLMetry** | Apache 2.0 | Vendor-neutral observability |

```python
# evaluation/observability.py

from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode

tracer = trace.get_tracer("agent.llm")

class TracedLLMProvider(LLMProvider):
    """LLM provider with OpenTelemetry tracing"""

    def __init__(self, base_provider: LLMProvider):
        self.base = base_provider

    def complete(self, messages: List[Dict], **kwargs) -> str:
        with tracer.start_as_current_span("llm.complete") as span:
            span.set_attribute("llm.provider", self.base.__class__.__name__)
            span.set_attribute("llm.model", kwargs.get("model", "default"))
            span.set_attribute("llm.input_tokens", self._count_tokens(messages))

            try:
                result = self.base.complete(messages, **kwargs)
                span.set_attribute("llm.output_tokens", self._count_tokens([{"content": result}]))
                span.set_status(Status(StatusCode.OK))
                return result
            except Exception as e:
                span.set_status(Status(StatusCode.ERROR, str(e)))
                raise
```

---

## 7. Deployment & Operations

### 7.1 Deployment Patterns

| Pattern | Use Case | Pros | Cons |
|---------|----------|------|------|
| **Serverless** | Low/variable traffic | Cost-efficient, auto-scaling | Cold starts |
| **Containerized** | Predictable workload | Full control, consistent | Infrastructure overhead |
| **Edge** | Low latency needed | Fast response | Limited model options |
| **Hybrid** | Mixed requirements | Best of both | Complexity |

### 7.2 Configuration as Code

```yaml
# deployment/agent-config.yaml

apiVersion: agent/v1
kind: AgentDeployment
metadata:
  name: production-agent
  version: "2.1.0"

spec:
  # Provider configuration
  providers:
    primary:
      name: anthropic
      model: claude-3-5-sonnet-20241022
      fallback: openai/gpt-4-turbo

    local:
      name: ollama
      model: llama3:70b
      use_for: ["sensitive_data"]

  # System prompt configuration
  prompts:
    core: ./prompts/core-identity.md
    modules:
      - ./prompts/modules/security.md
      - ./prompts/modules/devops.md
    examples: ./examples/

  # Tool configuration
  tools:
    mcp_servers:
      - name: filesystem
        config: ./mcp/filesystem.json
      - name: github
        config: ./mcp/github.json

    custom:
      - ./tools/custom_tools.py

  # Operational settings
  operations:
    max_tokens: 8192
    temperature: 0.7
    timeout_seconds: 120
    max_retries: 3

  # Monitoring
  observability:
    provider: langfuse
    project: production-agent
    traces: true
    metrics: true
```

### 7.3 Health Checks & Monitoring

```python
# deployment/health.py

from dataclasses import dataclass
from enum import Enum
from typing import Dict, List

class HealthStatus(Enum):
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"

@dataclass
class HealthCheck:
    name: str
    status: HealthStatus
    latency_ms: float
    details: Dict

class AgentHealthMonitor:
    """Monitor agent health across providers"""

    def __init__(self, providers: Dict[str, LLMProvider]):
        self.providers = providers

    def check_all(self) -> Dict[str, HealthCheck]:
        """Run health checks on all providers"""
        results = {}
        for name, provider in self.providers.items():
            results[name] = self._check_provider(name, provider)
        return results

    def _check_provider(self, name: str, provider: LLMProvider) -> HealthCheck:
        """Check individual provider health"""
        import time

        start = time.time()
        try:
            response = provider.complete([
                {"role": "user", "content": "Say 'OK' and nothing else."}
            ], max_tokens=10)
            latency = (time.time() - start) * 1000

            if "OK" in response:
                return HealthCheck(
                    name=name,
                    status=HealthStatus.HEALTHY,
                    latency_ms=latency,
                    details={"response": response}
                )
            else:
                return HealthCheck(
                    name=name,
                    status=HealthStatus.DEGRADED,
                    latency_ms=latency,
                    details={"response": response, "reason": "Unexpected response"}
                )
        except Exception as e:
            return HealthCheck(
                name=name,
                status=HealthStatus.UNHEALTHY,
                latency_ms=(time.time() - start) * 1000,
                details={"error": str(e)}
            )
```

**🆕 Automation Hooks (v1.1.0):**
For Claude Code, automation hooks available for automatic monitoring:
- **SessionStart hooks** (4): health check, dashboard, digest notification, rules reinforcement
- **SessionEnd hooks** (4): summary, continuity, metrics collection, evaluation
- **PreToolUse hooks** (16): budget check, safety diagnostics, usage limits, input validation
- **PostToolUse hooks** (18): metrics tracking, code review, tool chain analysis, cost tracking
- **Other hooks** (2): PostToolUseFailure, UserPromptSubmit
- **Total: 48 registrations** (42 files, consolidated; all audited, no bare excepts, with file locking)
Full documentation: `docs/AUTOMATION_SUMMARY.md`, `docs/PHASE2_EVENT_BASED_AUTOMATION.md`

---

## 8. Provider-Specific Considerations

### 8.1 Feature Comparison Matrix

| Feature | Anthropic | OpenAI | Google | Mistral | Local |
|---------|-----------|--------|--------|---------|-------|
| **Max Context** | 200K | 128K | 2M | 128K | Varies |
| **Tool Calling** | ✅ Native | ✅ Native | ✅ Native | ✅ Native | ⚠️ Limited |
| **Streaming** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Prompt Caching** | ✅ 5min TTL | ❌ | ✅ | ❌ | N/A |
| **Extended Thinking** | ✅ | ✅ o1/o3 | ✅ | ❌ | ❌ |
| **Computer Use** | ✅ | ✅ Operator | ✅ Mariner | ❌ | ❌ |
| **Image Input** | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| **JSON Mode** | ✅ | ✅ | ✅ | ✅ | ⚠️ |

### 8.2 API Differences

```python
# providers/differences.py

"""
Key API differences between providers.
This module documents patterns for handling differences.
"""

# Message format differences
ANTHROPIC_FORMAT = {
    "system": "system prompt goes in separate parameter",
    "messages": [{"role": "user", "content": "..."}]
}

OPENAI_FORMAT = {
    "messages": [
        {"role": "system", "content": "system prompt"},
        {"role": "user", "content": "..."}
    ]
}

# Tool call response differences
ANTHROPIC_TOOL_RESPONSE = {
    "type": "tool_use",
    "id": "toolu_xxx",
    "name": "tool_name",
    "input": {"param": "value"}
}

OPENAI_TOOL_RESPONSE = {
    "tool_calls": [{
        "id": "call_xxx",
        "type": "function",
        "function": {
            "name": "tool_name",
            "arguments": '{"param": "value"}'  # JSON string!
        }
    }]
}

# Handling these differences in abstraction layer
def normalize_tool_calls(response: Dict, provider: str) -> List[Dict]:
    """Normalize tool calls to common format"""
    if provider == "anthropic":
        return [{
            "id": tc["id"],
            "name": tc["name"],
            "arguments": tc["input"]
        } for tc in response.get("content", []) if tc.get("type") == "tool_use"]

    elif provider == "openai":
        return [{
            "id": tc["id"],
            "name": tc["function"]["name"],
            "arguments": json.loads(tc["function"]["arguments"])
        } for tc in response.get("tool_calls", [])]

    # Add more providers...
```

### 8.3 Cost Optimization by Provider

| Strategy | Anthropic | OpenAI | Google | Local |
|----------|-----------|--------|--------|-------|
| **Prompt Caching** | ✅ -90% cached | ❌ | ✅ -75% | N/A |
| **Batch API** | ✅ -50% | ✅ -50% | ⚠️ | N/A |
| **Model Routing** | Use Haiku | Use mini | Use Flash | Use 7B |
| **Context Compression** | Effective | Effective | Less needed | Critical |

---

## 9. Migration Strategies

### 9.1 Provider Migration Checklist

```markdown
## Migration Checklist: Provider A → Provider B

### Pre-Migration
- [ ] Audit current provider usage (calls, tokens, costs)
- [ ] Identify feature dependencies (caching, tools, context length)
- [ ] Test new provider with sample workloads
- [ ] Update abstraction layer for new provider
- [ ] Prepare rollback plan

### Migration Steps
- [ ] Deploy canary (5% traffic to new provider)
- [ ] Monitor quality metrics for 24-48 hours
- [ ] Gradually increase traffic (25%, 50%, 75%, 100%)
- [ ] Monitor for regressions at each step
- [ ] Update documentation and runbooks

### Post-Migration
- [ ] Verify cost projections
- [ ] Update alerting thresholds
- [ ] Archive old provider configuration
- [ ] Conduct retrospective
```

### 9.2 Gradual Migration Pattern

```python
# migration/gradual.py

import random
from typing import Dict

class GradualMigration:
    """
    Gradually migrate traffic between providers.
    Supports percentage-based routing and instant rollback.
    """

    def __init__(
        self,
        old_provider: LLMProvider,
        new_provider: LLMProvider,
        initial_percentage: float = 5.0
    ):
        self.old = old_provider
        self.new = new_provider
        self.new_percentage = initial_percentage
        self.metrics = {"old": [], "new": []}

    def complete(self, messages: List[Dict], **kwargs) -> str:
        """Route request based on migration percentage"""
        use_new = random.random() * 100 < self.new_percentage

        provider = self.new if use_new else self.old
        provider_name = "new" if use_new else "old"

        start = time.time()
        try:
            result = provider.complete(messages, **kwargs)
            self.metrics[provider_name].append({
                "latency": time.time() - start,
                "success": True
            })
            return result
        except Exception as e:
            self.metrics[provider_name].append({
                "latency": time.time() - start,
                "success": False,
                "error": str(e)
            })
            raise

    def increase_percentage(self, new_percentage: float):
        """Increase traffic to new provider"""
        self.new_percentage = min(100.0, new_percentage)

    def rollback(self):
        """Emergency rollback to old provider"""
        self.new_percentage = 0.0

    def get_comparison_metrics(self) -> Dict:
        """Compare performance between providers"""
        return {
            "old": self._summarize_metrics(self.metrics["old"]),
            "new": self._summarize_metrics(self.metrics["new"])
        }
```

---

## Appendix: Quick Reference

### A.1 Provider SDK Quick Start

```bash
# Install SDKs
pip install anthropic openai google-generativeai mistralai litellm

# Or use unified interface
pip install litellm
```

### A.2 Environment Variables

```bash
# Provider API Keys
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
export GOOGLE_API_KEY="..."
export MISTRAL_API_KEY="..."

# Aggregators
export OPENROUTER_API_KEY="..."
export LITELLM_API_KEY="..."

# Observability
export LANGFUSE_PUBLIC_KEY="..."
export LANGFUSE_SECRET_KEY="..."
```

### A.3 Model Identifiers

| Provider | Model ID Format | Example |
|----------|-----------------|---------|
| Anthropic | `claude-{version}-{date}` | `claude-3-5-sonnet-20241022` |
| OpenAI | `gpt-{version}` | `gpt-4-turbo`, `o1-preview` |
| Google | `gemini-{version}` | `gemini-1.5-pro` |
| Mistral | `mistral-{name}` | `mistral-large-latest` |
| LiteLLM | `{provider}/{model}` | `anthropic/claude-3-5-sonnet` |
| OpenRouter | `{provider}/{model}` | `anthropic/claude-3.5-sonnet` |

### A.4 Useful Links

| Resource | URL |
|----------|-----|
| **MCP Spec** | https://modelcontextprotocol.io/ |
| **A2A Protocol** | https://cloud.google.com/a2a |
| **LiteLLM Docs** | https://docs.litellm.ai/ |
| **OpenRouter** | https://openrouter.ai/docs |
| **Langfuse** | https://langfuse.com/docs |
| **LMSYS Arena** | https://chat.lmsys.org/ |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.1.2 | 2026-01-30 | New orchestration & production patterns: Dynamic Role Assignment (auto-routing to optimal agent/model), Safety Diagnostics Framework (pre-execution security checks), PostgreSQL production scaling (9 techniques for high-load databases) |
| 1.1.1 | 2026-01-29 | System-Reminder bypass documentation (GAP-ARCH-002) |
| 1.0.0 | 2026-01-25 | Initial release |

---

**Author:** Generated with Claude Agent Configuration Framework
**License:** MIT
**Repository:** https://github.com/<your-org>/claude-code-config
