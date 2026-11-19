# Flappy Bird Integrado (jogo educativo)

Um jogo no estilo "Flappy Bird" feito em **Godot 4.7**. O jogador controla um gato
**com a mão**, usando uma luva com sensor de distância (a **TechGlove**). No caminho:

- **obstáculos** que mostram problemas ambientais de lugares do Brasil (lixo na rua,
  esgoto no mar, balão de São João...). Bateu? A tela explica o problema e como ajudar;
- **bolhas com respostas de contas** (ex.: `7 + 5 = ?`). O jogador voa até a bolha certa.

São 3 fases: **Rua do Nordeste → Fortaleza → Rio de Janeiro**. Cada fase tem seu cenário,
seus obstáculos e contas mais difíceis (soma/subtração até 9, até 15 e tabuada).

---

## Como rodar

1. Abra o **Godot 4.7** e clique em *Importar* → escolha o arquivo `project.godot` desta pasta.
2. Aperte **F5** (ou o botão ▶). O jogo abre no menu.

| Controle | O que faz |
|---|---|
| Luva (TechGlove) | mão mais perto da mesa = gato mais alto |
| **M** | liga/desliga o controle pelo **mouse** (para testar sem a luva) |
| Espaço / clique | tenta de novo depois de perder |
| **Esc** | volta ao menu |

### Como a luva conversa com o jogo

O jogo **escuta** mensagens UDP na porta **5005** do próprio computador (`127.0.0.1`).
Cada mensagem é um texto JSON com a distância medida em centímetros:

```json
{"distancia": 12.5}
```

Quem lê o sensor da luva e manda essas mensagens é um programa separado (fora deste
projeto) rodando no mesmo PC. O código que recebe está em `luva/tech_glove.gd`.
Se nenhuma mensagem chegar por 1 segundo, o jogo considera a luva desconectada.

---

## Mapa das pastas

Cada pasta é **uma parte do jogo**, e a cena (`.tscn`) fica junto do script (`.gd`) dela.

```
flapy-bird-integrado/
├── menu/          Tela inicial (JOGAR, SKINS, SAIR)
├── jogo/          A partida: regras, pontuação, fases e placar
│   ├── main.tscn / main.gd    o "maestro": cria obstáculos e perguntas, conta pontos, troca de fase
│   ├── fases.gd               SÓ DADOS: fases, textos educativos e dicas  ← edite textos aqui
│   └── hud.tscn / hud.gd      placar, barra da fase, painel da conta e tela de fim
├── personagem/    O gato: movimento (luva ou mouse) e as skins (gato, cachorro, pombo)
├── luva/          Recebe a distância da TechGlove por UDP e filtra o ruído do sensor
├── obstaculos/    Obstáculo de cima/baixo (obstaculo) e objetos voando (projetil)
├── perguntas/     As bolhas de matemática
│   ├── contas.gd              sorteia a conta e as respostas erradas  ← mude a dificuldade aqui
│   ├── pergunta.gd            a coluna de bolhas que anda pela tela
│   └── bolha.gd               uma bolha com um número
├── cenarios/      Fundo de cada fase (camadas que rolam em velocidades diferentes)
├── assets/        Só arquivos de arte: imagens, fonte e ícones (nenhum código)
└── ferramentas/   Script que gera a pixel art das fases 2 e 3 (não faz parte do jogo)
```

> Os arquivos `.uid` e `.import` são criados pelo Godot. Não apague e não edite.

---

## Como uma partida funciona

```
menu ──JOGAR──▶ jogo/main.tscn
                  │
                  ├─ o gato começa a voar (personagem/player.gd emite "started")
                  │
                  ├─ a cada ~4 s o main.gd cria a próxima coisa na direita da tela:
                  │     obstáculo, obstáculo, PERGUNTA, obstáculo, obstáculo, PERGUNTA...
                  │
                  ├─ PERGUNTA ("modo pergunta"):
                  │     os obstáculos na frente do gato somem e nenhum novo aparece;
                  │     as bolhas param na lateral direita por 3 s (o chão continua rolando)
                  │     e depois andam até o gato; respondeu → os obstáculos voltam
                  │
                  ├─ passou pelo buraco ou acertou a conta → pontos + barra da fase anda
                  │     barra cheia → próxima fase (cenário e obstáculos mudam)
                  │
                  └─ bateu num obstáculo ou no chão → tela de fim com a explicação
                        (o texto vem de jogo/fases.gd)
```

---

## Onde mudar o quê

| Quero... | Arquivo |
|---|---|
| mudar um texto educativo ou uma dica | `jogo/fases.gd` |
| mudar quais obstáculos aparecem em cada fase | `jogo/fases.gd` (listas `cima`, `baixo`, `aereos`) |
| mudar a dificuldade das contas | `perguntas/contas.gd` (função `sortear`) |
| mudar velocidade (`velocidade_mundo`), tamanho do buraco, pontos, contas a cada N obstáculos | nó **Main** no Inspector do Godot (abra `jogo/main.tscn`) |
| mudar quanto tempo as bolhas ficam paradas | nó **Main** → *Perguntas de matematica* → `tempo_bolhas_paradas` |
| fazer errar a conta derrubar o gato | nó **Main** → *Perguntas de matematica* → `erro_encerra_jogo` |
| começar direto na fase 2 ou 3 (para testar) | nó **Main** → `fase_inicial` (0, 1 ou 2) |
| adicionar uma skin | `personagem/skins.gd` (lista `LIST`) + imagens em `assets/skins/` |
| ajustar o filtro do sensor da luva | nó **TechGlove** em `jogo/main.tscn` (Inspector) |

---

## Regras para a equipe

1. **Mova e renomeie arquivos sempre pelo Godot** (painel *FileSystem*), nunca pelo
   Explorador do Windows. As cenas guardam o caminho dos arquivos; o Godot atualiza
   esses caminhos sozinho, o Windows não, e o jogo quebra.
2. **Não crie pastas `_backup_...`.** O projeto usa **git**: cada versão salva com
   `git commit` pode ser recuperada depois. Antes de uma mudança grande, faça um commit.
3. Nomes de arquivos e pastas: minúsculas, sem acento, com `_` no lugar de espaço.
