//
//  ContentView.swift
//  GPTWrapper
//
//  Created by Minsang Choi on 5/25/24.
//

import SwiftUI
import OpenAI


class ChatController : ObservableObject {
    
    @Published var messages : [Message] = []
    @Published var isLoading: Bool = false
    @Published var streamingMessage: String = ""
    @Published var animationFinished : Bool = false


    let openAI = OpenAI(apiToken: " add your token here.")

    func sendNewMessage(content:String){
        let userMessage = Message(content: content, isUser: true)
        self.messages.append(userMessage)
        getBotReply()
    }
        
    func getBotReply() {
        let query = ChatQuery(
            messages: self.messages.map({
                .init(role: .user, content: $0.content)!
            }),
            model: .gpt3_5Turbo
        )
        
        self.isLoading = true
        self.streamingMessage = ""

        openAI.chatsStream(query: query) { partialResult in
            switch partialResult {
            case .success(let result):
                guard let choice = result.choices.first else {
                    return
                }
                guard let message = choice.delta.content else { return }
                DispatchQueue.main.async {
                    self.streamingMessage += message
                }
                

            case .failure(let error):
                print(error)
                //Handle chunk error here
            }
        } completion: { error in
            DispatchQueue.main.async {
                self.isLoading = false
                self.messages.append(Message(content: self.streamingMessage, isUser: false))
                self.streamingMessage = ""
            }

        }
    }
}

struct Message: Identifiable {
    var id: UUID = .init()
    var content: String
    var isUser: Bool
}

struct ContentView: View {
        
    @StateObject var chatController : ChatController = .init()
    @State private var selectedItem = "gpt-3.5 Turbo"
    @FocusState private var isTextFieldFocused: Bool
    @State private var changelayout : Bool = false
    @State private var logooffset : CGFloat = 100
    @State private var contentSize : CGSize = .zero
    @State private var previousContentHeight : CGFloat = 0
    @State private var totalContentHeight : CGFloat = 0
    @State private var previousContentCount : Int = 0
    @State private var isUserScrolling : Bool = false
    @State private var loaderscale : CGFloat = 0
    @State private var scrolltoBottom : Bool = false
    @State private var maindotScale : CGFloat = 1
    @State private var delta : CGFloat = 0
    @State private var scrollStop : Bool = false
    @State private var buttonScale : CGFloat = 1


    
    
    @State var string:String = ""

    
    let items = [ "gpt 3.5 Turbo", "gpt 4", "gpt-4o",]
    
    var body: some View {
        NavigationView{
            VStack{
                if chatController.messages.isEmpty {
                    VStack{
                        Spacer()
                        Circle()
                            .frame(width:40,height:40)
                            .scaleEffect(maindotScale)
                            .onAppear {
                                maindotScale = 12
                                withAnimation(.spring()){
                                    maindotScale = 1
                                }
                            }
                        Text("Hi, how can I help?")
                            .opacity(maindotScale)
                            .bold()
                        Spacer()
                    }
                    .offset(y:logooffset)
                    .onAppear{
                        withAnimation(.spring()){
                            logooffset = 0
                        }
                    }
                } else {
                    ScrollViewReader { proxy in
                        ZStack{
                            ScrollView {
                                VStack{
                                    ForEach(chatController.messages) {
                                        message in
                                        MessageView(message: message)
                                            .id(message.id)
                                            .background(GeometryReader { c -> Color in
                                                DispatchQueue.main.async {
                                                    if message.isUser == false {
                                                        let id = chatController.messages[chatController.messages.count-1].id

                                                        if id == message.id {
                                                            delta = c.frame(in: .named(message.id)).size.height
                                                        }
                                                        if delta > 360 && previousContentHeight > 800 {
                                                            scrollStop = true
                                                        }
                                                    } else {
                                                        delta = 0
                                                        scrollStop = false
                                                    }
                                                }
                                                return Color.clear
                                            })
                                    }
                                }
                                .id("scrollview")
                                .background(GeometryReader { g -> Color in
                                    DispatchQueue.main.async {
                                        let contentSize = g.frame(in: .named("scrollview")).height

                                        if chatController.messages.count > previousContentCount {
                                            proxy.scrollTo("scrollToEnd",anchor:.top)
                                            previousContentCount = chatController.messages.count
                                        }
                                        
                                        if contentSize > previousContentHeight {
                                            if scrollStop == false {
                                                proxy.scrollTo("scrollToEnd",anchor:.top)
                                            }
                                            previousContentHeight = contentSize
                                        }
                                    }
                                    return Color.clear
                                })


                                if chatController.isLoading == true {
                                    Circle()
                                        .frame(width:20,height:20)
                                        .scaleEffect(loaderscale)
                                        .onAppear {
                                            loaderscale = 0
                                            withAnimation(.spring().repeatForever(autoreverses: true)) {
                                                loaderscale = 1
                                            }
                                        }
                                }
                                Color.clear
                                    .frame(height: 1)
                                    .id("scrollToEnd")
                            }
                            .id("sview")
                            if scrollStop == true {
                                ZStack{
                                    Circle()
                                        .frame(width: 40,height:40)
                                        .foregroundColor(.iconcolor)
                                        .shadow(color:.black.opacity(0.2),radius: /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)
                                    Image(systemName: "arrow.down")
                                        .resizable()
                                        .foregroundColor(.highlight)
                                        .frame(width:12,height:12)
                                        .bold()
                                }
                                .scaleEffect(buttonScale)
                                .offset(y:UIScreen.main.bounds.height/2-120)
                                .onTapGesture {
                                    withAnimation(.spring()){
                                        buttonScale = 0
                                        proxy.scrollTo("scrollToEnd",anchor:.top)
                                    }
                                }
                                .onAppear {
                                    withAnimation(.spring().delay(0.2)){
                                        buttonScale = 1
                                    }
                                }
                                
                            }
                        }

                    }
                }
                HStack{
                    TextField("Message",text:self.$string,axis: .vertical)
                        .padding(8)
                        .background(.gray.opacity(0.1))
                        .cornerRadius(12)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            delta = 0
                            self.chatController.sendNewMessage(content: string)
                            string = ""
                            scrollStop = false
                        }
                        .onAppear {
                            isTextFieldFocused = true
                        }
                        .onChange(of: isTextFieldFocused) {
                            if isTextFieldFocused {
                                withAnimation(.linear(duration: 0.1)){
                                    changelayout = true
                                }
                                
                            } else {
                                withAnimation(.linear(duration: 0.1)){
                                    changelayout = false
                                }
                            }
                        }
                    if changelayout {
                        Button{
                            self.chatController.sendNewMessage(content: string)
                            string = ""
                        } label: {
                            Text("Send")
                                .foregroundStyle(.highlight)
                                .bold()
                                .padding(.leading,8)
                        }
                    } else {
                        
                    }
                }
                .padding(20)
            }
            .navigationBarTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MessageView: View {
    
    var message: Message
    
    @StateObject var chatController : ChatController = .init()
    @State private var bubbleoffest : CGFloat = 60
    @State private var currentIndex: Int = 0
    @State private var timer: Timer? = nil
    @State private var displayedText = ""


    
    var body: some View {


        Group {

            if message.isUser {
                HStack{
                    Spacer()
                    Text(message.content)
                        .padding(16)
                        .multilineTextAlignment(.leading)
                        .background(.gray.opacity(0.5))
                        .foregroundColor(.highlight)
                        .cornerRadius(12)
                }
                .offset(y:bubbleoffest)
                .onAppear{
                    withAnimation(.spring()){
                        bubbleoffest = 0
                    }
                    
                }
            } else {
                VStack{
                    HStack{
                        Image("oailogo")
                            .resizable()
                            .tint(.white)
                            .frame(width:20,height:20)
                        Text("ChatGPT")
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.highlight)
                            .bold()
                        Spacer()
                    }
                    HStack{
                        Text(displayedText)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.highlight)
                            .lineSpacing(2)
                            .onAppear {
                                startTypingAnimation()
                            }
                        Spacer()
                    }
                    .padding(.top,4)
                }
            }
        }.padding(20)
    }
    func startTypingAnimation() {

        timer?.invalidate()
        currentIndex = 0
        displayedText = ""
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            if currentIndex < message.content.count {
                let index = message.content.index(message.content.startIndex, offsetBy: currentIndex)
                displayedText.append(message.content[index])
                currentIndex += 1
            } else {
                timer?.invalidate()
            }
        }
}

}



#Preview {
    ContentView()
}
