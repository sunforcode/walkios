import SwiftUI

/// 被两个及以上业务域使用的业务组件命名空间。
///
/// 依据 specs/README.md R-DEP：Feature 之间不引用对方内部类型；跨域复用的业务组件与其投影
/// 放在 `Features/Shared/`。Shared 只放组件、投影和格式化工具，不放页面与 ViewModel，
/// 且自身不依赖任何业务域（由 FeatureBoundaryTests 强制）。组件 ID 与行为不因归属调整而改变。
enum SharedBusinessComponents {}
