//
//  IconHelper.swift
//  Motion
//

import SwiftUI

enum AppIcon: String, CaseIterable {
    case gift
    case code
    case rocket
    case heart
    case star
    case lightningBolt
    case python
    case swiftUI
    case xcode
    case github
    case figma
    case react
    case firebase

    var assetName: String? {
        switch self {
        case .code:     return "CodeIcon"
        case .python:   return "PythonIcon"
        case .swiftUI:  return "SwiftUIIcon"
        case .xcode:    return "XcodeIcon"
        case .github:   return "GitHubIcon"
        case .figma:    return "FigmaIcon"
        case .react:    return "ReactIcon"
        case .firebase: return "FirebaseIcon"
        default:        return nil
        }
    }

    var sfSymbolName: String {
        switch self {
        case .gift:          return "gift"
        case .code:          return "chevron.left.forwardslash.chevron.right"
        case .rocket:        return "paperplane.fill"
        case .heart:         return "heart"
        case .star:          return "star"
        case .lightningBolt: return "bolt"
        case .python:        return "chevron.left.forwardslash.chevron.right"
        case .swiftUI:       return "swift"
        case .xcode:         return "hammer"
        case .github:        return "cat"
        case .figma:         return "paintbrush"
        case .react:         return "atom"
        case .firebase:      return "flame"
        }
    }
}

struct AppIconView: View {
    let icon: AppIcon
    var size: CGFloat = 32
    var color: Color = .primary

    var body: some View {
        if let assetName = icon.assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: icon.sfSymbolName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(color)
        }
    }
}

#Preview("App Icons") {
    LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ], spacing: 20) {
        ForEach(AppIcon.allCases, id: \.self) { icon in
            VStack(spacing: 8) {
                AppIconView(icon: icon, size: 48, color: .accentColor)
                Text(icon.rawValue)
                    .font(.caption)
            }
        }
    }
    .padding()
}
