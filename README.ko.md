# Jetpack Paging for SwiftUI

> **Android Jetpack Paging3의 사고방식을 SwiftUI로 그대로 가져온 Pagination 라이브러리**

## 🎬 샘플 앱

이 라이브러리를 실제로 사용한 SwiftUI 샘플 앱입니다:

👉 **Movie App (SwiftUI + Paging)**  
https://github.com/hhp227study/Movie

`Jetpack-Paging-for-SwiftUI`는 Android의 **Jetpack Paging3**에 익숙한 개발자가
SwiftUI에서도 **동일한 개념·동일한 흐름·동일한 책임 분리**로 페이징을 구현할 수 있도록 만든 라이브러리입니다.

특히 다음과 같은 개발자를 대상으로 합니다:

- Android Paging3를 사용해본 **멀티플랫폼(Android + iOS) 개발자**
- SwiftUI에서 대규모 리스트 페이징 구조를 **아키텍처적으로 정리하고 싶은 개발자**
- 단순 `onAppear` 기반 pagination이 아닌, **명확한 LoadState / PagingState**를 원하시는 분

---

## ✨ Why This Library?

SwiftUI에는 Jetpack Paging3와 같은 **공식 Paging 라이브러리**가 존재하지 않습니다.

대부분의 SwiftUI 페이징은 다음과 같은 한계를 가집니다:

- 페이지 상태(page, hasMore)를 ViewModel에서 직접 관리
- 로딩 / 에러 상태가 View마다 제각각
- Android ↔ iOS 간 아키텍처 불일치

이 라이브러리는 Android Paging3의 핵심 개념을 그대로 가져옵니다:

- `PagingSource`
- `Pager`
- `PagingData`
- `LoadState (refresh / append)`

👉 **Android Paging3를 알고 있다면, 별도의 학습 없이 바로 사용 가능**합니다.

---

## 🧠 Concept Mapping (Paging3 ↔ SwiftUI)

| Android Paging3 | Jetpack Paging for SwiftUI |
|----------------|----------------------------|
| `PagingSource<Key, Value>` | `PagingSource<Key, Value>` |
| `Pager` | `Pager` |
| `PagingData<T>` | `PagingData<T>` |
| `LoadState` | `LoadState` |
| `append / refresh` | `append / refresh` |
| `LazyColumn` | `List / LazyVStack` |

> **이 라이브러리는 API 이름과 책임 구조를 의도적으로 Paging3와 맞췄습니다.**

---

## 📦 Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/hhp227/Jetpack-Paging-for-SwiftUI", from: "1.0.0")
```

---

## 🚀 Quick Start

### 1️⃣ Define PagingSource (Same as Android)

```swift
final class PostPagingSource: PagingSource<Int, Post> {

    override func load(params: LoadParams<Int>) async throws -> LoadResult<Int, Post> {
        let page = params.key ?? 1
        let response = try await PostAPI.fetchPosts(page: page)

        return .page(
            data: response.posts,
            prevKey: page == 1 ? nil : page - 1,
            nextKey: response.posts.isEmpty ? nil : page + 1
        )
    }
}
```

---

### 2️⃣ Create Pager

```swift
let pager = Pager(
    config: PagingConfig(pageSize: 20),
    pagingSourceFactory: { PostPagingSource() }
)
```

---

### 3️⃣ ViewModel

```swift
@MainActor
final class PostListViewModel: ObservableObject {

    let pagingData: PagingData<Post>

    init() {
        self.pagingData = pager.flow
    }
}
```

---

### 4️⃣ SwiftUI View (Paging3 스타일)

```swift
struct PostListScreen: View {

    @StateObject private var viewModel = PostListViewModel()

    var body: some View {
        List {
            ForEach(viewModel.pagingData.items) { post in
                PostRow(post: post)
            }

            switch viewModel.pagingData.loadState.append {
            case .loading:
                ProgressView()
            case .error(let error):
                Text(error.localizedDescription)
            default:
                EmptyView()
            }
        }
        .refreshable {
            await viewModel.pagingData.refresh()
        }
    }
}
```

---

## 🔄 LoadState Handling

```swift
enum LoadState {
    case idle
    case loading
    case error(Error)
}
```

Paging3와 동일하게 다음 상태를 제공합니다:

- `loadState.refresh`
- `loadState.append`

---

## 🧩 Architecture Philosophy

이 라이브러리는 다음 원칙을 따릅니다:

- View는 **상태를 관찰만 한다**
- Paging 로직은 **ViewModel / Paging 계층의 책임**
- UI는 데이터 로딩 로직을 알지 못한다

이는 Android Paging3의 핵심 설계 철학과 동일합니다.

---

## 👥 Who Should Use This?

✅ Android Paging3 경험자

✅ Android ↔ iOS 멀티플랫폼 개발자

✅ SwiftUI에서 대규모 리스트를 다루는 앱

✅ Paging 로직을 재사용 가능한 구조로 관리하고 싶은 팀

---

## ⚠️ What This Is NOT

- UI Pager (Carousel) 라이브러리 ❌
- 단순 `onAppear` 기반 pagination ❌
- CoreData 전용 페이징 솔루션 ❌

---

## 📌 Roadmap

- [ ] Retry / Error Recovery API
- [ ] RemoteMediator 스타일 Local + Remote Sync
- [ ] iOS Sample App
- [ ] Documentation 강화

---

## 🙌 Credits

Inspired by **Android Jetpack Paging3**

Maintained by **hhp227**

---

## ⭐️ Final Note

> SwiftUI에는 Paging3가 없었습니다.
>
> 그래서 만들었습니다.

Android Paging3의 사고방식을 SwiftUI에서도 그대로 사용해보세요.

