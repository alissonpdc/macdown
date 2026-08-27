# Agent Rules — MacDown

## GATES de Aprovação

Antes de concluir qualquer implementação, TODOS os GATES abaixo devem ser cumpridos:

### 1. Build sem warnings

```bash
cd MarkdownCore && make app
```

- O build deve ser concluído com **zero warnings**.
- Qualquer warning é motivo para correção antes de prosseguir.

### 2. Todos os testes passando

```bash
cd MarkdownCore && make test
```

- Todos os testes devem passar.
- Falhas em testes bloqueiam a aprovação.

### 3. Commit (Conventional Commit)

Ao fechar uma implementação e cumprir todos os GATES anteriores, realizar commit seguindo o padrão **Conventional Commit**:

```
<type>(<scope>): <descrição curta>

[corpo opcional]

[footer opcional: fixes #<issue>]
```

**Types:**
- `feat` — nova funcionalidade
- `fix` — correção de bug
- `refactor` — refatoração sem mudança de comportamento
- `docs` — documentação
- `test` — testes
- `chore` — manutenção, dependências, CI

**Exemplo:**
```
feat(sidebar): implementar navegação por setas no estilo Finder
```

## Ordem de Execução

1. Implementar a mudança
2. Rodar `make app` → verificar zero warnings
3. Rodar `make test` → verificar todos passando
4. Realizar commit convencional
