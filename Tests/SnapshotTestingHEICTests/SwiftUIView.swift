//
//  SwiftUIView.swift
//  
//
//  Created by Emanuel Cunha on 19/05/2023.
//

#if os(iOS)
import SwiftUI

struct SwiftUIView: View {
    var body: some View {
        Text("Test SnapshotTestingHEIC SwiftUI")
            .font(.system(size: 64))
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIView()
    }
}
#endif
