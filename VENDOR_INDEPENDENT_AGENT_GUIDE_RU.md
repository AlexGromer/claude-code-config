# Вендоронезависимое руководство по разработке агентов
## Универсальная методология создания production AI-агентов

**Версия:** 1.2.0
**Дата:** 2026-01-25
**Последнее обновление:** 2026-02-06
**Язык:** Русский
**Целевая аудитория:** Разработчики, создающие LLM-агентов с любым провайдером
**Совместимость:** OpenAI, Anthropic, Google, Mistral, Cohere, локальные LLM

> **🆕 v1.1.1 Update:** Добавлено примечание про System-Reminder Problem (GAP-ARCH-002). Claude Code CLI оборачивает claudeMd в `<system-reminder>may or may not be relevant</system-reminder>`. **Решение:** 3-tier priority override через `--append-system-prompt` (CORE_INSTRUCTIONS.md + claude-wrapper). **Документация:** `docs/SYSTEM_REMINDER_BYPASS.md`

---

## Содержание

1. [Введение и ландшафт провайдеров](#1-введение-и-ландшафт-провайдеров)
2. [Основы архитектуры](#2-основы-архитектуры)
3. [Проектирование системных промптов](#3-проектирование-системных-промптов)
4. [Паттерны интеграции инструментов](#4-паттерны-интеграции-инструментов)
5. [Мультиагентная оркестрация](#5-мультиагентная-оркестрация)
6. [Оценка и контроль качества](#6-оценка-и-контроль-качества)
7. [Развёртывание и эксплуатация](#7-развёртывание-и-эксплуатация)
8. [Особенности провайдеров](#8-особенности-провайдеров)
9. [Стратегии миграции](#9-стратегии-миграции)
10. [Приложение: Краткий справочник](#приложение-краткий-справочник)

---

## 1. Введение и ландшафт провайдеров

### 1.1 Почему важна вендоронезависимость

Создание вендоронезависимых AI-агентов обеспечивает:

| Преимущество | Описание |
|--------------|----------|
| **Гибкость** | Переключение провайдеров по стоимости, производительности или доступности |
| **Снижение рисков** | Избежание vendor lock-in, устаревания API, изменения цен |
| **Оптимизация** | Использование разных моделей для разных задач (роутинг) |
| **Соответствие требованиям** | Выполнение требований по локализации данных с локальными моделями |
| **Контроль затрат** | Использование конкуренции между провайдерами |

### 1.2 Ландшафт провайдеров (2026)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      ЛАНДШАФТ LLM-ПРОВАЙДЕРОВ 2026                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  КОММЕРЧЕСКИЕ (Cloud API)                                                  │
│  ────────────────────────                                                  │
│  • Anthropic: Claude Opus 4.5, Sonnet 4.5, Haiku 3.7                       │
│  • OpenAI: GPT-5.2, GPT-4.5-turbo, o3-pro (reasoning)                      │
│  • Google: Gemini 3, Gemini 2.5 Flash (2M контекст)                        │
│  • Mistral: Large 2, Codestral, Ministral                                  │
│  • Cohere: Command R+, Embed v3                                             │
│  • xAI: Grok 4.1                                                            │
│                                                                             │
│  OPEN SOURCE (Self-hosted)                                                  │
│  ─────────────────────────                                                  │
│  • Meta: Llama 4 (405B, 70B, 8B)                                           │
│  • Mistral: Mistral Large 2 (open weights)                                 │
│  • Alibaba: Qwen 3 серия                                                    │
│  • DeepSeek: DeepSeek V3.2, R1 (reasoning)                                 │
│  • 01.AI: Yi-1.5 серия                                                      │
│                                                                             │
│  РЕГИОНАЛЬНЫЕ                                                               │
│  ────────────                                                               │
│  • Россия: YandexGPT 5, GigaChat MAX                                       │
│  • Китай: Baidu ERNIE 5.0, ByteDance Doubao                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.3 Матрица выбора модели

| Сценарий использования | Рекомендуемые модели | Обоснование |
|------------------------|---------------------|-------------|
| **Универсальный ассистент** | Claude Sonnet, GPT-4.5 | Баланс качества и стоимости |
| **Сложные рассуждения** | Claude Opus, o3-pro, DeepSeek R1 | Глубокие reasoning-способности |
| **Генерация кода** | Claude Sonnet, Codestral, DeepSeek Coder | Оптимизация под код |
| **Длинный контекст** | Gemini 3 (2M), Claude (200k) | Расширенное контекстное окно |
| **Экономия бюджета** | Haiku, GPT-4.5-mini, Llama 4 8B | Низкая стоимость за токен |
| **Приватность/On-Premise** | Llama 4, Mistral, Qwen 3 | Self-hosted варианты |
| **Русский язык** | YandexGPT, GigaChat, Claude | Нативная поддержка русского |

---

## 2. Основы архитектуры

### 2.1 Универсальная архитектура агента

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    УНИВЕРСАЛЬНАЯ АРХИТЕКТУРА АГЕНТА                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      СЛОЙ ПРИЛОЖЕНИЯ                                 │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐               │   │
│  │  │   CLI   │  │   Web   │  │   API   │  │   IDE   │               │   │
│  │  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘               │   │
│  └───────┴────────────┴────────────┴────────────┴───────────────────────┘   │
│                                    │                                        │
│  ┌─────────────────────────────────▼───────────────────────────────────┐   │
│  │                      СЛОЙ ОРКЕСТРАЦИИ                                │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│  │  │    Роутер    │  │  Супервайзер │  │    Память    │              │   │
│  │  │(модель/задача)│  │  (workflow)  │  │(персистенция)│              │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘              │   │
│  └─────────────────────────────────┬───────────────────────────────────┘   │
│                                    │                                        │
│  ┌─────────────────────────────────▼───────────────────────────────────┐   │
│  │                СЛОЙ АБСТРАКЦИИ ПРОВАЙДЕРА                            │   │
│  │  ┌────────────────────────────────────────────────────────────┐    │   │
│  │  │  LiteLLM / OpenRouter / Кастомная обёртка                   │    │   │
│  │  └────────────────────────────────────────────────────────────┘    │   │
│  │       │           │           │           │           │            │   │
│  │  ┌────▼────┐ ┌────▼────┐ ┌────▼────┐ ┌────▼────┐ ┌────▼────┐     │   │
│  │  │Anthropic│ │ OpenAI  │ │ Google  │ │ Mistral │ │Локальные│     │   │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│  ┌─────────────────────────────────▼───────────────────────────────────┐   │
│  │                      СЛОЙ ИНСТРУМЕНТОВ                               │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐               │   │
│  │  │   MCP   │  │ Function│  │Выполнение│ │ Браузер │               │   │
│  │  │ Серверы │  │ Calling │  │   кода  │  │   Use   │               │   │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Слой абстракции провайдера

**Ключевой принцип:** Все вызовы LLM проходят через слой абстракции, который нормализует различия между провайдерами.

#### Вариант A: LiteLLM (Рекомендуется)

```python
# LiteLLM предоставляет единый API для 100+ провайдеров
from litellm import completion

# Один и тот же код работает с любым провайдером
response = completion(
    model="claude-3-5-sonnet-20241022",  # или "gpt-4", "gemini/gemini-pro"
    messages=[{"role": "user", "content": "Привет"}]
)

# Переключение провайдера — это изменение конфигурации
response = completion(
    model="gpt-4-turbo",
    messages=[{"role": "user", "content": "Привет"}]
)
```

#### Вариант B: OpenRouter (API Gateway)

```python
import openai

client = openai.OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key="ваш-openrouter-ключ"
)

# Доступ к любой модели через единый API
response = client.chat.completions.create(
    model="anthropic/claude-3.5-sonnet",
    messages=[{"role": "user", "content": "Привет"}]
)
```

#### Вариант C: Кастомная обёртка

```python
from abc import ABC, abstractmethod
from typing import List, Dict, Any

class LLMProvider(ABC):
    """Абстрактный базовый класс для LLM-провайдеров"""

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

class YandexGPTProvider(LLMProvider):
    """Провайдер для YandexGPT (Россия)"""
    def __init__(self, api_key: str, folder_id: str, model: str = "yandexgpt-lite"):
        self.api_key = api_key
        self.folder_id = folder_id
        self.model = model

    def complete(self, messages: List[Dict], **kwargs) -> str:
        # Реализация для YandexGPT API
        import requests
        response = requests.post(
            "https://llm.api.cloud.yandex.net/foundationModels/v1/completion",
            headers={"Authorization": f"Api-Key {self.api_key}"},
            json={
                "modelUri": f"gpt://{self.folder_id}/{self.model}",
                "messages": messages
            }
        )
        return response.json()["result"]["alternatives"][0]["message"]["text"]

# Фабричный паттерн для выбора провайдера
def get_provider(provider_name: str, **kwargs) -> LLMProvider:
    providers = {
        "anthropic": AnthropicProvider,
        "openai": OpenAIProvider,
        "yandex": YandexGPTProvider,
        # Добавляйте провайдеры по необходимости
    }
    return providers[provider_name](**kwargs)
```

### 2.3 Управление конфигурацией

```yaml
# config.yaml - Конфигурация провайдеров на основе окружения
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

  yandex:
    api_key: ${YANDEX_API_KEY}
    folder_id: ${YANDEX_FOLDER_ID}
    models:
      default: yandexgpt
      fast: yandexgpt-lite

  local:
    base_url: http://localhost:11434/v1
    models:
      default: llama3:70b
      fast: llama3:8b

routing:
  # Маршрутизация задач к подходящим моделям
  code_review: anthropic.default
  complex_reasoning: anthropic.reasoning
  quick_answers: openai.fast
  sensitive_data: local.default
  russian_text: yandex.default
```

---

## 3. Проектирование системных промптов

### 3.1 Модульная архитектура промптов

**Ключевой принцип:** Системные промпты должны быть модульными, кэшируемыми и провайдеронезависимыми.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 МОДУЛЬНАЯ АРХИТЕКТУРА ПРОМПТОВ                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  УРОВЕНЬ 1: БАЗОВАЯ ИДЕНТИЧНОСТЬ (Статический, Кэшируемый)                 │
│  ─────────────────────────────────────────────────────────                 │
│  • Персона и возможности агента                                            │
│  • Операционные принципы и ограничения                                     │
│  • Рекомендации по формату ответов                                         │
│  • Размер: 1-3K токенов | TTL кэша: 5 мин                                  │
│                                                                             │
│  УРОВЕНЬ 2: ДОМЕННЫЕ МОДУЛИ (Полустатический, Кэшируемый)                  │
│  ────────────────────────────────────────────────────────                  │
│  • Доменно-специфичные знания (безопасность, DevOps и т.д.)                │
│  • Специализированные процедуры и чек-листы                                │
│  • Размер: 2-5K токенов на модуль | TTL кэша: 5 мин                        │
│                                                                             │
│  УРОВЕНЬ 3: КОНТЕКСТ (Динамический, Не кэшируется)                         │
│  ─────────────────────────────────────────────────                         │
│  • Детали текущей задачи                                                   │
│  • История разговора                                                       │
│  • Предпочтения пользователя для сессии                                    │
│  • Размер: Переменный                                                      │
│                                                                             │
│  УРОВЕНЬ 4: ПРИМЕРЫ (Полустатический, Кэшируемый)                          │
│  ────────────────────────────────────────────────                          │
│  • Few-shot примеры для качества                                           │
│  • Доменно-специфичные демонстрации                                        │
│  • Размер: 1-3K токенов | TTL кэша: 5 мин                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Универсальный шаблон системного промпта

```markdown
# Конфигурация агента

## Идентичность
Ты [ИМЯ_АГЕНТА], [ОПИСАНИЕ_РОЛИ].

## Возможности
- [Возможность 1]
- [Возможность 2]
- [Возможность 3]

## Операционные принципы
1. **Точность прежде всего** — Проверяй факты, указывай на неопределённость
2. **Структурное мышление** — Разбивай сложные задачи на шаги
3. **Прозрачность** — Объясняй рассуждения и решения
4. **Безопасность** — Следуй лучшим практикам безопасности

## Формат ответов
- Используй markdown для структурированного вывода
- Включай блоки кода с тегами языка
- Приводи примеры где уместно

## Ограничения
- Никогда не выдумывай информацию или цитаты
- Задавай уточняющие вопросы когда требования неясны
- Запрашивай подтверждение перед деструктивными операциями

## Доступные инструменты
[Описания инструментов автоматически внедряются в зависимости от провайдера]
```

### 3.3 Оптимизации промптов под провайдеров

| Провайдер | Оптимизация | Примечания |
|-----------|-------------|------------|
| **Anthropic** | Используй XML-теги для структуры | `<context>`, `<instructions>`, `<output>` |
| **OpenAI** | Используй чёткие секции с заголовками | GPT-модели хорошо реагируют на иерархическую структуру |
| **Google** | Включай явные примеры | Gemini выигрывает от in-context примеров |
| **Mistral** | Держи промпты краткими | Оптимизация под меньшее контекстное окно |
| **Локальные** | Упрощай инструкции | Меньшие модели требуют более чётких, коротких промптов |
| **YandexGPT** | Пиши на русском | Нативная поддержка русского языка |

### 3.4 Библиотека Few-Shot примеров

```python
# examples_library.py - Провайдеронезависимое управление примерами

from pathlib import Path
from typing import List, Dict

class ExamplesLibrary:
    """
    Управление few-shot примерами по доменам.
    Примеры — это провайдеронезависимые markdown-файлы.
    """

    def __init__(self, examples_dir: str = "./examples"):
        self.examples_dir = Path(examples_dir)
        self.index = self._load_index()

    def get_examples(self, domain: str, task_type: str, count: int = 3) -> str:
        """
        Получить релевантные примеры для домена и типа задачи.

        Args:
            domain: напр., "security", "devops", "coding"
            task_type: напр., "code_review", "debugging", "explanation"
            count: Количество примеров для возврата

        Returns:
            Отформатированная строка примеров для внедрения в промпт
        """
        examples = self._find_matching_examples(domain, task_type, count)
        return self._format_examples(examples)

    def _format_examples(self, examples: List[Dict]) -> str:
        """Форматирование примеров для внедрения в промпт"""
        output = "## Примеры\n\n"
        for i, ex in enumerate(examples, 1):
            output += f"### Пример {i}: {ex['title']}\n\n"
            output += f"**Ввод:**\n{ex['input']}\n\n"
            output += f"**Вывод:**\n{ex['output']}\n\n"
            output += "---\n\n"
        return output

# Структура файлов примеров:
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

## 4. Паттерны интеграции инструментов

### 4.1 Универсальный формат определения инструментов

**Ключевой принцип:** Определяй инструменты в провайдеронезависимом формате, затем конвертируй в специфичные для провайдера схемы.

```python
# tools/base.py - Универсальное определение инструментов

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
    """Провайдеронезависимое определение инструмента"""
    name: str
    description: str
    parameters: List[ToolParameter]
    handler: Callable

    def to_anthropic(self) -> Dict:
        """Конвертация в формат инструментов Anthropic"""
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
        """Конвертация в формат function calling OpenAI"""
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
        """Конвертация в формат инструментов Google Gemini"""
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

# Пример определения инструмента
file_read_tool = UniversalTool(
    name="read_file",
    description="Чтение содержимого файла из файловой системы",
    parameters=[
        ToolParameter(
            name="file_path",
            type=ParameterType.STRING,
            description="Абсолютный путь к файлу для чтения"
        ),
        ToolParameter(
            name="encoding",
            type=ParameterType.STRING,
            description="Кодировка файла",
            required=False,
            default="utf-8"
        )
    ],
    handler=lambda file_path, encoding="utf-8": open(file_path, encoding=encoding).read()
)
```

### 4.2 Интеграция MCP (Model Context Protocol)

MCP обеспечивает стандартизированную интеграцию инструментов между провайдерами.

```python
# tools/mcp_adapter.py - Интеграция MCP

import json
from typing import Dict, Any, List

class MCPAdapter:
    """
    Адаптер для MCP (Model Context Protocol) серверов.
    MCP теперь стандарт Linux Foundation (2025).
    """

    def __init__(self, server_config: Dict[str, Any]):
        self.servers = {}
        for name, config in server_config.items():
            self.servers[name] = self._connect_server(config)

    def list_tools(self) -> List[UniversalTool]:
        """Получить все доступные инструменты из MCP-серверов"""
        tools = []
        for server_name, server in self.servers.items():
            server_tools = server.list_tools()
            for tool in server_tools:
                tools.append(self._mcp_to_universal(tool, server_name))
        return tools

    def call_tool(self, tool_name: str, arguments: Dict) -> Any:
        """Выполнить инструмент через MCP"""
        server_name, local_name = self._parse_tool_name(tool_name)
        return self.servers[server_name].call_tool(local_name, arguments)

    def _mcp_to_universal(self, mcp_tool: Dict, server_name: str) -> UniversalTool:
        """Конвертация определения MCP-инструмента в универсальный формат"""
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

# Пример конфигурации MCP-сервера
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

### 4.3 Паттерны вызова инструментов

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ПАТТЕРНЫ ВЫЗОВА ИНСТРУМЕНТОВ                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ПАТТЕРН 1: ОДИНОЧНЫЙ ВЫЗОВ                                                │
│  ──────────────────────────                                                │
│  Пользователь → LLM → Вызов → Результат → LLM → Ответ                      │
│  Применение: Простые операции (чтение файла, API-вызов)                    │
│                                                                             │
│  ПАТТЕРН 2: АГЕНТНЫЙ ЦИКЛ (ReAct)                                          │
│  ────────────────────────────────                                          │
│  Пользователь → LLM → Мысль → Действие → Наблюдение → ... → Ответ          │
│  Применение: Сложные задачи, требующие нескольких шагов                    │
│                                                                             │
│  ПАТТЕРН 3: ПАРАЛЛЕЛЬНЫЕ ВЫЗОВЫ                                            │
│  ──────────────────────────────                                            │
│  Пользователь → LLM → [Инструмент 1, 2, 3] → Слияние → Ответ               │
│  Применение: Независимые операции (получение нескольких файлов)            │
│                                                                             │
│  ПАТТЕРН 4: ВЛОЖЕННЫЕ ВЫЗОВЫ                                               │
│  ───────────────────────────                                               │
│  Пользователь → LLM → Инструмент A → (внутри вызов B) → Результат          │
│  Применение: Составные операции (поиск, затем чтение)                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Мультиагентная оркестрация

### 5.1 Паттерны мультиагентных систем (2026)

| Паттерн | Описание | Лучше всего для | Фреймворки |
|---------|----------|-----------------|------------|
| **Supervisor** | Центральный агент делегирует специалистам | Сложные workflow | LangGraph, CrewAI |
| **Router** | Маршрутизирует запросы к подходящему агенту | Смешанные типы задач | Semantic Kernel |
| **Arbiter** | Несколько агентов предлагают, один решает | Важные решения | AWS Bedrock |
| **Swarm** | Агенты сотрудничают динамически | Открытое исследование | OpenAI Swarm |
| **Pipeline** | Последовательная передача между агентами | Структурированные workflow | AutoGen |

### 5.2 Реализация паттерна Supervisor

```python
# orchestration/supervisor.py

from typing import List, Dict, Any
from dataclasses import dataclass
import json

@dataclass
class AgentSpec:
    """Спецификация специализированного агента"""
    name: str
    description: str
    capabilities: List[str]
    model: str  # Идентификатор провайдер/модель
    system_prompt: str
    tools: List[str]

class Supervisor:
    """
    Агент-супервайзер, делегирующий специалистам.
    Провайдеронезависимая реализация.
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
        Обработка пользовательского запроса через паттерн supervisor.

        1. Супервайзер анализирует запрос
        2. Делегирует подходящему специалисту(-ам)
        3. Агрегирует результаты
        4. Возвращает финальный ответ
        """
        # Шаг 1: Планирование
        plan = self._create_plan(user_request)

        # Шаг 2: Выполнение
        results = []
        for step in plan['steps']:
            agent = self.agents[step['agent']]
            result = self._delegate_to_agent(agent, step['task'])
            results.append({
                'agent': step['agent'],
                'task': step['task'],
                'result': result
            })

        # Шаг 3: Синтез
        return self._synthesize_results(user_request, results)

    def _create_plan(self, request: str) -> Dict:
        """Супервайзер создаёт план выполнения"""
        planning_prompt = f"""Проанализируй запрос и создай план выполнения.

Доступные агенты:
{self._format_agents()}

Запрос: {request}

Верни JSON-план со шагами, указывая какой агент выполняет какую задачу."""

        response = self.provider.complete([
            {"role": "user", "content": planning_prompt}
        ])
        return json.loads(response)

    def _delegate_to_agent(self, agent: AgentSpec, task: str) -> str:
        """Выполнение задачи специализированным агентом"""
        # Можно использовать разных провайдеров для разных агентов
        agent_provider = get_provider_for_model(agent.model)

        return agent_provider.complete([
            {"role": "system", "content": agent.system_prompt},
            {"role": "user", "content": task}
        ])

# Пример использования
agents = [
    AgentSpec(
        name="code_reviewer",
        description="Проверяет код на баги, уязвимости и best practices",
        capabilities=["анализ кода", "security review", "проверка стиля"],
        model="anthropic/claude-3-5-sonnet",
        system_prompt="Ты эксперт по code review...",
        tools=["read_file", "search_code"]
    ),
    AgentSpec(
        name="researcher",
        description="Исследует технические темы и суммирует находки",
        capabilities=["веб-поиск", "поиск документации", "суммаризация"],
        model="openai/gpt-4-turbo",
        system_prompt="Ты технический исследователь...",
        tools=["web_search", "read_url"]
    )
]

supervisor = Supervisor(provider=get_provider("anthropic"), agents=agents)
result = supervisor.run("Проверь модуль аутентификации и исследуй лучшие практики OAuth 2.1")
```

### 5.3 Интеграция A2A Protocol (Google 2025)

```python
# orchestration/a2a.py - Поддержка Agent-to-Agent Protocol

"""
A2A Protocol обеспечивает интероперабельность между агентами разных вендоров.
Анонсирован Google в 2025 как дополнение к MCP.
"""

from dataclasses import dataclass
from typing import Optional, List, Dict
import requests

@dataclass
class A2ACapability:
    """Возможность, объявленная через A2A"""
    name: str
    description: str
    input_schema: Dict
    output_schema: Dict

class A2AClient:
    """Клиент для коммуникации по A2A Protocol"""

    def __init__(self, agent_url: str):
        self.agent_url = agent_url
        self.capabilities = self._discover_capabilities()

    def _discover_capabilities(self) -> List[A2ACapability]:
        """Обнаружение возможностей удалённого агента"""
        response = requests.get(f"{self.agent_url}/.well-known/a2a")
        return [A2ACapability(**cap) for cap in response.json()['capabilities']]

    def invoke(self, capability: str, input_data: Dict) -> Dict:
        """Вызов возможности на удалённом агенте"""
        response = requests.post(
            f"{self.agent_url}/invoke/{capability}",
            json=input_data,
            headers={"Content-Type": "application/json"}
        )
        return response.json()

# Пример: Использование внешнего агента через A2A
external_agent = A2AClient("https://agent.example.com")
result = external_agent.invoke("summarize_document", {"url": "https://..."})
```

---

## 6. Оценка и контроль качества

### 6.1 Фреймворк оценки

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ФРЕЙМВОРК ОЦЕНКИ                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  УРОВЕНЬ 1: UNIT-МЕТРИКИ                                                   │
│  ───────────────────────                                                   │
│  • Latency (p50, p95, p99)                                                 │
│  • Использование токенов (input, output, cached)                           │
│  • Стоимость запроса                                                       │
│  • Частота ошибок                                                          │
│                                                                             │
│  УРОВЕНЬ 2: МЕТРИКИ КАЧЕСТВА                                               │
│  ──────────────────────────                                                │
│  • Процент завершения задач                                                │
│  • Точность (domain-specific)                                              │
│  • Фактическая согласованность                                             │
│  • Следование инструкциям                                                  │
│                                                                             │
│  УРОВЕНЬ 3: АГЕНТНЫЕ МЕТРИКИ                                               │
│  ──────────────────────────                                                │
│  • Успешность вызовов инструментов                                         │
│  • Эффективность агентного цикла (шагов до завершения)                     │
│  • Восстановление после ошибок                                             │
│  • Использование контекста                                                 │
│                                                                             │
│  УРОВЕНЬ 4: БИЗНЕС-МЕТРИКИ                                                 │
│  ────────────────────────                                                  │
│  • Удовлетворённость пользователей (NPS, рейтинги)                         │
│  • Ценность выполненных задач                                              │
│  • Сэкономленное время vs ручная работа                                    │
│  • ROI                                                                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Паттерн LLM-as-a-Judge

```python
# evaluation/llm_judge.py

from typing import List, Dict, Any, Optional
import json

class LLMJudge:
    """
    Использование LLM для оценки вывода другой LLM.
    Провайдеронезависимая реализация.
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
        Оценка ответа по критериям.

        Args:
            task: Исходная задача/вопрос
            response: Ответ для оценки
            criteria: Список критериев оценки
            reference: Опциональный эталонный ответ

        Returns:
            Оценки и обоснования
        """
        eval_prompt = f"""Оцени следующий ответ.

Задача: {task}

Ответ для оценки:
{response}

{f"Эталонный ответ: {reference}" if reference else ""}

Критерии оценки:
{chr(10).join(f"- {c}" for c in criteria)}

По каждому критерию укажи:
1. Оценку (1-5)
2. Обоснование

Верни JSON в формате:
{{
  "scores": {{"критерий": оценка, ...}},
  "reasoning": {{"критерий": "объяснение", ...}},
  "overall_score": float,
  "summary": "краткая общая оценка"
}}"""

        result = self.judge.complete([
            {"role": "user", "content": eval_prompt}
        ])
        return json.loads(result)

# Стандартные критерии оценки
STANDARD_CRITERIA = [
    "Точность: Фактически ли корректна информация?",
    "Полнота: Полностью ли ответ адресует задачу?",
    "Ясность: Понятен ли и хорошо организован ответ?",
    "Релевантность: Остаётся ли ответ в теме?",
    "Безопасность: Избегает ли ответ вредоносного контента?"
]

RUSSIAN_CRITERIA = [
    "Грамматика: Корректен ли русский язык?",
    "Стиль: Соответствует ли стиль задаче?",
    "Терминология: Правильно ли использованы термины?"
]
```

### 6.3 Стек observability

| Инструмент | Лицензия | Лучше всего для |
|------------|----------|-----------------|
| **LangSmith** | Коммерческий | Приложения на LangChain |
| **Langfuse** | MIT OSS | Независимые, self-hosted |
| **Helicone** | OSS + SaaS | Быстрый старт, фокус на OpenAI |
| **Phoenix** | OSS | OpenTelemetry-native |
| **OpenLLMetry** | Apache 2.0 | Вендоронезависимый observability |

```python
# evaluation/observability.py

from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode

tracer = trace.get_tracer("agent.llm")

class TracedLLMProvider(LLMProvider):
    """LLM-провайдер с OpenTelemetry-трейсингом"""

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

## 7. Развёртывание и эксплуатация

### 7.1 Паттерны развёртывания

| Паттерн | Сценарий | Преимущества | Недостатки |
|---------|----------|--------------|------------|
| **Serverless** | Низкий/переменный трафик | Экономичный, автомасштабирование | Cold starts |
| **Контейнеры** | Предсказуемая нагрузка | Полный контроль, стабильность | Накладные расходы |
| **Edge** | Требуется низкая latency | Быстрый отклик | Ограниченный выбор моделей |
| **Гибридный** | Смешанные требования | Лучшее из обоих | Сложность |

### 7.2 Configuration as Code

```yaml
# deployment/agent-config.yaml

apiVersion: agent/v1
kind: AgentDeployment
metadata:
  name: production-agent
  version: "2.1.0"

spec:
  # Конфигурация провайдеров
  providers:
    primary:
      name: anthropic
      model: claude-3-5-sonnet-20241022
      fallback: openai/gpt-4-turbo

    local:
      name: ollama
      model: llama3:70b
      use_for: ["sensitive_data"]

    russian:
      name: yandex
      model: yandexgpt
      use_for: ["russian_text"]

  # Конфигурация системных промптов
  prompts:
    core: ./prompts/core-identity.md
    modules:
      - ./prompts/modules/security.md
      - ./prompts/modules/devops.md
    examples: ./examples/

  # Конфигурация инструментов
  tools:
    mcp_servers:
      - name: filesystem
        config: ./mcp/filesystem.json
      - name: github
        config: ./mcp/github.json

    custom:
      - ./tools/custom_tools.py

  # Операционные настройки
  operations:
    max_tokens: 8192
    temperature: 0.7
    timeout_seconds: 120
    max_retries: 3

  # Мониторинг
  observability:
    provider: langfuse
    project: production-agent
    traces: true
    metrics: true
```

### 7.3 Health-проверки и мониторинг

```python
# deployment/health.py

from dataclasses import dataclass
from enum import Enum
from typing import Dict, List
import time

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
    """Мониторинг здоровья агента по провайдерам"""

    def __init__(self, providers: Dict[str, LLMProvider]):
        self.providers = providers

    def check_all(self) -> Dict[str, HealthCheck]:
        """Запуск health-проверок на всех провайдерах"""
        results = {}
        for name, provider in self.providers.items():
            results[name] = self._check_provider(name, provider)
        return results

    def _check_provider(self, name: str, provider: LLMProvider) -> HealthCheck:
        """Проверка здоровья отдельного провайдера"""
        start = time.time()
        try:
            response = provider.complete([
                {"role": "user", "content": "Скажи 'OK' и ничего больше."}
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
                    details={"response": response, "reason": "Неожиданный ответ"}
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
Для Claude Code доступны automation hooks для автоматического мониторинга:
- **SessionStart hooks** (4): health check, dashboard, digest notification, rules reinforcement
- **SessionEnd hooks** (4): summary, continuity, metrics collection, evaluation
- **PreToolUse hooks** (16): budget check, safety diagnostics, usage limits, input validation
- **PostToolUse hooks** (18): metrics tracking, code review, tool chain analysis, cost tracking
- **Other hooks** (2): PostToolUseFailure, UserPromptSubmit
- **Итого: 48 регистраций** (42 файла, консолидированы; все проаудированы, нет bare excepts, file locking)
Полная документация: `docs/AUTOMATION_SUMMARY.md`, `docs/PHASE2_EVENT_BASED_AUTOMATION.md`

---

## 8. Особенности провайдеров

### 8.1 Матрица сравнения возможностей

| Возможность | Anthropic | OpenAI | Google | Mistral | Локальные | YandexGPT |
|-------------|-----------|--------|--------|---------|-----------|-----------|
| **Макс. контекст** | 200K | 128K | 2M | 128K | Разный | 32K |
| **Tool Calling** | Нативный | Нативный | Нативный | Нативный | Ограничен | Нативный |
| **Streaming** | Да | Да | Да | Да | Да | Да |
| **Кэширование промптов** | 5 мин TTL | Нет | Да | Нет | N/A | Нет |
| **Extended Thinking** | Да | o1/o3 | Да | Нет | Нет | Нет |
| **Computer Use** | Да | Operator | Mariner | Нет | Нет | Нет |
| **Ввод изображений** | Да | Да | Да | Да | Частично | Да |
| **JSON Mode** | Да | Да | Да | Да | Частично | Да |
| **Русский язык** | Хорошо | Хорошо | Хорошо | Средне | Разный | Отлично |

### 8.2 Различия API

```python
# providers/differences.py

"""
Ключевые различия API между провайдерами.
Этот модуль документирует паттерны для обработки различий.
"""

# Различия в формате сообщений
ANTHROPIC_FORMAT = {
    "system": "системный промпт в отдельном параметре",
    "messages": [{"role": "user", "content": "..."}]
}

OPENAI_FORMAT = {
    "messages": [
        {"role": "system", "content": "системный промпт"},
        {"role": "user", "content": "..."}
    ]
}

YANDEX_FORMAT = {
    "modelUri": "gpt://folder_id/model_name",
    "messages": [
        {"role": "system", "text": "системный промпт"},
        {"role": "user", "text": "..."}
    ]
}

# Различия в ответах на tool call
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
            "arguments": '{"param": "value"}'  # JSON-строка!
        }
    }]
}

# Обработка этих различий в слое абстракции
def normalize_tool_calls(response: Dict, provider: str) -> List[Dict]:
    """Нормализация tool calls в общий формат"""
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

    # Добавляйте другие провайдеры...
```

### 8.3 Оптимизация затрат по провайдерам

| Стратегия | Anthropic | OpenAI | Google | Локальные | YandexGPT |
|-----------|-----------|--------|--------|-----------|-----------|
| **Кэширование промптов** | -90% кэшир. | Нет | -75% | N/A | Нет |
| **Batch API** | -50% | -50% | Частично | N/A | Нет |
| **Роутинг моделей** | Haiku | mini | Flash | 7B | lite |
| **Сжатие контекста** | Эффективно | Эффективно | Менее нужно | Критично | Важно |

---

## 9. Стратегии миграции

### 9.1 Чек-лист миграции провайдера

```markdown
## Чек-лист миграции: Провайдер A → Провайдер B

### До миграции
- [ ] Аудит текущего использования (вызовы, токены, затраты)
- [ ] Идентификация зависимостей от функций (кэширование, tools, context length)
- [ ] Тестирование нового провайдера на образцах нагрузки
- [ ] Обновление слоя абстракции для нового провайдера
- [ ] Подготовка плана отката

### Шаги миграции
- [ ] Развёртывание canary (5% трафика на новый провайдер)
- [ ] Мониторинг метрик качества 24-48 часов
- [ ] Постепенное увеличение трафика (25%, 50%, 75%, 100%)
- [ ] Мониторинг регрессий на каждом шаге
- [ ] Обновление документации и runbooks

### После миграции
- [ ] Проверка прогнозов по затратам
- [ ] Обновление порогов алертинга
- [ ] Архивация конфигурации старого провайдера
- [ ] Ретроспектива
```

### 9.2 Паттерн постепенной миграции

```python
# migration/gradual.py

import random
import time
from typing import Dict, List

class GradualMigration:
    """
    Постепенная миграция трафика между провайдерами.
    Поддерживает процентную маршрутизацию и мгновенный откат.
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
        """Маршрутизация запроса на основе процента миграции"""
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
        """Увеличение трафика на новый провайдер"""
        self.new_percentage = min(100.0, new_percentage)

    def rollback(self):
        """Экстренный откат на старый провайдер"""
        self.new_percentage = 0.0

    def get_comparison_metrics(self) -> Dict:
        """Сравнение производительности провайдеров"""
        return {
            "old": self._summarize_metrics(self.metrics["old"]),
            "new": self._summarize_metrics(self.metrics["new"])
        }

    def _summarize_metrics(self, metrics: List[Dict]) -> Dict:
        """Суммаризация метрик"""
        if not metrics:
            return {"count": 0}

        latencies = [m["latency"] for m in metrics]
        successes = [m["success"] for m in metrics]

        return {
            "count": len(metrics),
            "success_rate": sum(successes) / len(successes),
            "avg_latency": sum(latencies) / len(latencies),
            "p95_latency": sorted(latencies)[int(len(latencies) * 0.95)] if len(latencies) > 20 else max(latencies)
        }
```

---

## Приложение: Краткий справочник

### A.1 Быстрый старт с SDK провайдеров

```bash
# Установка SDK
pip install anthropic openai google-generativeai mistralai litellm

# Или использование унифицированного интерфейса
pip install litellm

# Для российских провайдеров
pip install yandexcloud  # YandexGPT
```

### A.2 Переменные окружения

```bash
# API-ключи провайдеров
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
export GOOGLE_API_KEY="..."
export MISTRAL_API_KEY="..."

# Российские провайдеры
export YANDEX_API_KEY="..."
export YANDEX_FOLDER_ID="..."
export GIGACHAT_API_KEY="..."

# Агрегаторы
export OPENROUTER_API_KEY="..."
export LITELLM_API_KEY="..."

# Observability
export LANGFUSE_PUBLIC_KEY="..."
export LANGFUSE_SECRET_KEY="..."
```

### A.3 Идентификаторы моделей

| Провайдер | Формат ID модели | Пример |
|-----------|------------------|--------|
| Anthropic | `claude-{version}-{date}` | `claude-3-5-sonnet-20241022` |
| OpenAI | `gpt-{version}` | `gpt-4-turbo`, `o1-preview` |
| Google | `gemini-{version}` | `gemini-1.5-pro` |
| Mistral | `mistral-{name}` | `mistral-large-latest` |
| YandexGPT | `yandexgpt` / `yandexgpt-lite` | `yandexgpt` |
| LiteLLM | `{provider}/{model}` | `anthropic/claude-3-5-sonnet` |
| OpenRouter | `{provider}/{model}` | `anthropic/claude-3.5-sonnet` |

### A.4 Полезные ссылки

| Ресурс | URL |
|--------|-----|
| **MCP Spec** | https://modelcontextprotocol.io/ |
| **A2A Protocol** | https://cloud.google.com/a2a |
| **LiteLLM Docs** | https://docs.litellm.ai/ |
| **OpenRouter** | https://openrouter.ai/docs |
| **Langfuse** | https://langfuse.com/docs |
| **LMSYS Arena** | https://chat.lmsys.org/ |
| **YandexGPT Docs** | https://cloud.yandex.ru/docs/yandexgpt/ |
| **GigaChat Docs** | https://developers.sber.ru/docs/ru/gigachat/ |

### A.5 Глоссарий

| Термин | Описание |
|--------|----------|
| **Agent** | LLM-система, способная выполнять действия и использовать инструменты |
| **MCP** | Model Context Protocol — стандарт интеграции инструментов |
| **A2A** | Agent-to-Agent Protocol — протокол взаимодействия агентов |
| **Tool Calling** | Возможность LLM вызывать внешние функции |
| **Few-shot** | Техника обучения на нескольких примерах в промпте |
| **Prompt Caching** | Кэширование системных промптов для снижения latency и cost |
| **ReAct** | Reason + Act — паттерн агентного reasoning |
| **Supervisor** | Центральный агент, координирующий работу специалистов |
| **Observability** | Наблюдаемость системы через метрики, логи и трейсы |
| **Canary Deployment** | Развёртывание на малую часть трафика для тестирования |

---

## История версий

| Версия | Дата | Изменения |
|--------|------|-----------|
| 1.1.2 | 2026-01-30 | Новые паттерны оркестрации и production: Dynamic Role Assignment (автовыбор агента/модели), Safety Diagnostics Framework (pre-execution security checks), PostgreSQL production scaling (9 техник для высоконагруженных БД) |
| 1.1.1 | 2026-01-29 | Документация System-Reminder bypass (GAP-ARCH-002) |
| 1.0.0 | 2026-01-25 | Первый релиз |

---

**Автор:** Создано с помощью Claude Agent Configuration Framework
**Лицензия:** MIT
**Репозиторий:** https://github.com/<your-org>/claude-code-config
