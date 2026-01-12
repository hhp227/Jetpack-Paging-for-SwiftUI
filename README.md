# Jetpack Paging for SwiftUI

> **Jetpack Paging3 mental model, brought to SwiftUI**

`Jetpack-Paging-for-SwiftUI` is a pagination library that allows you to use **the same concepts, responsibilities, and data flow as Android Jetpack Paging3** in SwiftUI.

This library is especially designed for:

- **Multi-platform developers (Android + iOS)** familiar with Paging3
- SwiftUI developers who want a **well-structured, architecture-first pagination solution**
- Teams that want **consistent paging architecture across Android and iOS**

---

## ✨ Why This Library Exists

SwiftUI does **not** provide an official pagination library comparable to Android’s Jetpack Paging3.

As a result, most SwiftUI pagination implementations:

- Manually manage page numbers and loading state in ViewModels
- Scatter loading / error handling logic across views
- Diverge significantly from Android paging architecture

This library directly ports the **core ideas of Paging3** into SwiftUI:

- `PagingSource`
- `Pager`
- `PagingData`
- `LoadState (refresh / append)`

👉 **If you know Paging3, you already know how to use this library.**

---

## 🧠 Concept Mapping (Android ↔ SwiftUI)

| Android Jetpack Paging3 | Jetpack Paging for SwiftUI |
|-------------------------|----------------------------|
| `PagingSource<Key, Value>` | `PagingSource<Key, Value>` |
| `Pager` | `Pager` |
| `PagingData<T>` | `PagingData<T>` |
| `LoadState` | `LoadState` |
| `append / refresh` | `append / refresh` |
| `LazyColumn` | `List / LazyVStack` |

> **API naming and responsibilities are intentionally aligned with Paging3.**

---

## 📦 Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/hhp227/Jetpack-Paging-for-SwiftUI", from: "1.0.0")
```

---

## 🚀 Quick Start

### 1️⃣ Define a PagingSource (Same Pattern as Android)

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

### 2️⃣ Create a Pager

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

### 4️⃣ SwiftUI View (Paging3-style usage)

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

Available states mirror Paging3 behavior:

- `loadState.refresh`
- `loadState.append`

---

## 🧩 Architecture Philosophy

This library follows the same core principles as Jetpack Paging3:

- Views **observe state only**
- Paging logic lives outside the UI layer
- UI is completely decoupled from data-loading mechanics

This enables scalable, testable, and platform-consistent paging architecture.

---

## 👥 Who Should Use This?

✅ Developers experienced with Android Paging3

✅ Multi-platform (Android + iOS) teams

✅ SwiftUI apps with large, paginated lists

✅ Projects that value **architectural consistency**

---

## ⚠️ What This Library Is NOT

- UI pager / carousel library ❌
- Simple `onAppear`-based pagination helper ❌
- CoreData-only paging solution ❌

---

## 📌 Roadmap

- [ ] Retry / error recovery API
- [ ] RemoteMediator-style local + remote synchronization
- [ ] Sample iOS app
- [ ] Expanded documentation

---

## 🙌 Credits

Inspired by **Android Jetpack Paging3**

Maintained by **hhp227**

---

## ⭐️ Final Note

> SwiftUI did not have Paging3.
>
> So this library brings the Paging3 mental model to SwiftUI.

If you already use Paging3 on Android, this library should feel immediately familiar.

