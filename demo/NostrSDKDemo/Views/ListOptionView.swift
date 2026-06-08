//
//  ListOptionView.swift
//  NostrSDKDemo
//
//  Created by Joel Klabo on 6/14/23.
//

import SwiftUI

struct ListOptionView: View {
    var destinationView: AnyView
    var imageName: String
    var labelText: String
    var useAssetImage: Bool = false

    var body: some View {
        NavigationLink(destination: destinationView) {
            Label {
                Text(labelText)
            } icon: {
                if useAssetImage {
                    Image(imageName)
                        .renderingMode(.template)
                } else {
                    Image(systemName: imageName)
                }
            }
        }
    }
}

struct ListOptionView_Previews: PreviewProvider {
    static var previews: some View {
        ListOptionView(destinationView: AnyView(GenerateKeyDemoView()), imageName: "key", labelText: "Key Generation")
    }
}
