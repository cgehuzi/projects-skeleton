# Обновление проекта из skeleton

Проект создаётся из `projects-skeleton` копией каркаса (Модель A) и со временем обрастает
своим. Этот документ описывает, как **доставлять последующие изменения skeleton** в уже
разошедшийся проект.

Коротко: skeleton подключается как git-remote `upstream`, обновления вливаются `merge`/
`cherry-pick`. Бесконфликтность достигается дисциплиной границ (см. ниже), а не магией.

## Разовая настройка проекта

> ⚠️ Создавайте проект **с сохранением git-истории** skeleton (`fork` или
> `git clone` + смена `origin`). НЕ используйте GitHub «Use this template» — он рвёт
> историю, и тогда слияние идёт через `--allow-unrelated-histories` со сплошными конфликтами.

```bash
# в репозитории проекта
git remote add upstream https://github.com/cgehuzi/projects-skeleton
git fetch upstream --tags
```

## Доставка обновлений

```bash
git fetch upstream --tags
# посмотреть, что изменилось между нашей версией и целевой
git log --oneline <текущая-версия>..v1.5.0

# влить релиз целиком…
git merge v1.5.0
# …или точечно один фикс
git cherry-pick <commit-sha>

# разрешить конфликты (только в файлах, которые проект редактировал), затем:
make build && make up
make migrate
make test
```

## Граница: что «принадлежит» skeleton, а что проекту

Чем меньше проект правит skeleton-файлы, тем чище слияния. Держим поверхности раздельно.

### Skeleton-managed — НЕ редактируем в проекте (кастомизация через точки расширения)

- `docker/**` (Dockerfile, конфиги, proxy)
- `compose.yaml`, `compose.prod.yaml`, `.dockerignore`
- `Makefile`
- `.github/workflows/**`
- `docs/**`
- `.editorconfig`, `.gitignore`
- `.env.example`, `.env.prod.example`
- `stubs/**` (шаблоны для `make init`)
- `CLAUDE.md` (корневой и по слоям)

Эти файлы обновляются из upstream. Нужна своя настройка — см. «Точки расширения».

> В skeleton `backend/`/`frontend/` **пустые**. Каркасы создаёт `make init` уже в
> проекте (Model B) — поэтому весь код приложения изначально project-owned, конфликтов
> с upstream по нему нет (skeleton его не содержит).

### Project-owned — правим свободно (skeleton сюда не лезет)

- Весь каркас приложения: `backend/**`, `frontend/**` (создан `make init`, закоммичен проектом).
- Зависимости: `package-core` и прочие пакеты (composer/npm) — версионируются per-project.
- Локальное окружение: `.env`, `backend/.env`, `compose.override.yaml` (skeleton их не трекает).

## Точки расширения (вместо правки skeleton-файлов)

- **Сервисы/тома/порты Docker** → `compose.override.yaml` (см. `compose.override.example.yaml`).
  Docker Compose автоматически мёржит его поверх `compose.yaml`.
- **Переменные окружения** → `.env` (Docker-стек) и `backend/.env` (Laravel).
- **Общая архитектурная начинка** → зависимость `package-core`, а не копирование в проект.
- **CI** → переиспользуемый workflow по версии (`uses: ...@vX`), а не копия YAML (см.
  `.github/workflows/`).

## Версионирование skeleton

- Релизы тегируются: `v1.0.0`, `v1.1.0`, …
- Значимые изменения и шаги миграции описываются в `CHANGELOG.md`.
- Проект подтягивает обновления по тегам **по порядку** и читает заметки миграции.

## Когда git-слияний становится мало

Под эту задачу есть спец-инструменты: [`copier`](https://copier.readthedocs.io)
(`copier update` — 3-way применение изменений шаблона) или `cruft`. Это Python-тулинг
поверх PHP/JS-стека — вводить по необходимости, на старте хватает git + дисциплины.
