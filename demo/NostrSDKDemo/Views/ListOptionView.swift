import SwiftUI

struct ListOptionView: View {
    var destinationView: AnyView
    var customImageName: String
    var labelText: String

    var body: some View {
        NavigationLink(destination: destinationView) {
            HStack {
                Image(customImageName)
                    .resizable()
                    .frame(width: 24, height: 24)
                Text(labelText)
            }
        }
    }
}

struct ListOptionView_Previews: PreviewProvider {
    static var previews: some View {
        ListOptionView(destinationView:
        AnyView(GenerateKeyDemoView()), customImageName: "network", labelText: "Custom Icon")
    }
}
