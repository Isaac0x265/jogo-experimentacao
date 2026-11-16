# FlapyBirdIntegrado

Jogo 2D em Godot com um gato voador, obstáculos ambientais e três fases:
Rua do Nordeste, Fortaleza e Rio de Janeiro. Inclui menu, seleção de skin,
pontuação, transição de cenários e mensagens de conscientização.

Esta é a branch `atual`, destinada ao desenvolvimento. O ZIP original e as
cópias históricas estão preservados na branch `backup`.

## Abrir o projeto

1. Importe `flapy-bird-integrado/project.godot` no Godot. A configuração
   existente declara a versão 4.7 e o renderizador Forward Plus.
2. Execute o projeto com F5 para iniciar pelo menu.
3. No jogo, use Espaço, seta para cima, W, clique ou toque para voar.
   Esc retorna ao menu.

O editor recria o cache `.godot/` ao importar o projeto.

## Estrutura

| Caminho dentro de `flapy-bird-integrado/` | Responsabilidade |
| --- | --- |
| `project.godot` | Configuração, cena inicial `scenes/menu.tscn` e autoload `Skins`. |
| `scenes/` | Menu, partida, personagem, obstáculos, projéteis e cenários. |
| `scripts/main.gd` | Fases, pontuação, geração de obstáculos, mensagens e efeitos. |
| `scripts/player.gd` | Movimento, entrada, animação e estados do personagem. |
| `scripts/menu.gd`, `scripts/menu_cursor.gd` | Navegação do menu e seleção de skin. |
| `scripts/skins.gd` | Catálogo de skins e persistência da seleção. |
| `scripts/obstaculo.gd`, `scripts/projetil.gd` | Obstáculos e objetos no ar. |
| `scripts/scenery.gd`, `scripts/scenery_layer.gd` | Rolagem e desenho do cenário procedural. |
| `assets/` | Imagens de cenários, personagem, obstáculos e interface; fonte e licença. |

`scenes/scenery.tscn` e `scripts/scenery_layer.gd` formam um cenário procedural
anterior. Foram mantidos como recursos do projeto: não são cópias nas pastas
de backup, embora as três fases atuais utilizem cenas específicas.

As configurações `*.import` e os identificadores `*.gd.uid` são versionados.
O diretório `.godot/` é cache local e fica ignorado pelo Git.

## Branches e backups

| Branch | Conteúdo |
| --- | --- |
| `atual` | Projeto organizado para desenvolvimento, sem ZIP nem pastas de backup. |
| `backup` | Projeto preservado, ZIP original e as duas pastas `_backup_antes_*`. |
| `main` | Commit original `64d3415`, contendo somente o ZIP. |

Na branch `backup`, dentro de `flapy-bird-integrado/`:

- `_backup_antes_rua_nordeste/`: scripts e cenas anteriores à inclusão da Rua
  do Nordeste e dos obstáculos, conforme o `LEIA.txt` de 14/11/2026.
- `_backup_antes_grafico_v2/`: scripts e cenas anteriores à melhoria gráfica,
  conforme o `LEIA.txt` de 14/11/2026.

Essas pastas são cópias parciais, não projetos completos executáveis.
O README da branch `backup` detalha a preservação e a comparação com o ZIP.

Para consultar o backup e depois voltar ao desenvolvimento:

```sh
git switch backup
git switch atual
```

Salve alterações em um commit antes de trocar de branch. Registre novas
versões com commits em vez de criar outras pastas de backup no projeto.

## Verificação da organização

O código, as cenas e os recursos da versão atual foram preservados. Foram
verificadas 43 referências diretas a recursos, sem arquivos faltando.
A execução do jogo não foi testada: o executável do Godot não estava
disponível no PATH do ambiente utilizado para esta organização.
