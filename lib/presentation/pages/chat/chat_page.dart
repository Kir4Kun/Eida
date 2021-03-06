import 'package:auto_route/auto_route.dart';
import 'package:eida/application/auth/auth_bloc.dart';
import 'package:eida/application/chat/mic/mic_bloc.dart';
import 'package:eida/presentation/routes/router.gr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'dart:async';

import '../../../application/chat/chat_bloc.dart';
import '../../../injection.dart';

class ChatPage extends HookWidget with AutoRouteWrapper {
  final String chatType;

  const ChatPage({Key? key, required this.chatType}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final username = (context.read<AuthBloc>().state as Authenticated).user.name.getOrCrash();

    final _scrollController = useScrollController();

    final ChatBloc _chatBloc = getIt<ChatBloc>()..add(ChatEvent.getChat(chatType));
    return WillPopScope(
      onWillPop: () async {
        context.router.replace(const DashboardRoute());
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Chat'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          controller: _scrollController,
          child: BlocBuilder<ChatBloc, ChatState>(
            bloc: _chatBloc,
            builder: (context, state) => state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error) => const Center(child: Text('There is no conversation for this topic')),
              loaded: (_, currentChat, __, finished) => Column(
                children: [
                  ListView.builder(
                    itemCount: currentChat.chatItems.length,
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 10, bottom: 10),
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final chatItem = currentChat.chatItems[index];
                      final user = chatItem.user.getOrCrash();
                      var message = chatItem.message.getOrCrash();

                      if (index == 0) {
                        message = '$message, $username';
                      }

                      return Container(
                        padding: const EdgeInsets.only(left: 14, right: 14, top: 5, bottom: 10),
                        child: Align(
                          alignment: user == 'bot' ? Alignment.topLeft : Alignment.topRight,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: user == 'bot' ? Colors.grey.shade200 : Colors.blue[200],
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Text(message, style: const TextStyle(fontSize: 15)),
                          ),
                        ),
                      );
                    },
                  ),
                  BlocConsumer<MicBloc, MicState>(
                    listener: (context, state) {
                      final chatWords = (_chatBloc.state as ChatLoaded).currentChat.chatItems.last.message.getOrCrash();

                      if (state.lastWords.isNotEmpty) {
                        if (chatWords.toLowerCase().replaceAll(',', '').contains(state.lastWords.toLowerCase())) {
                          _chatBloc.add(const ChatEvent.nextChat());
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please say "$chatWords", you said "${state.lastWords}"'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                      Timer(const Duration(milliseconds: 10), () => _scrollController.jumpTo(_scrollController.position.maxScrollExtent));
                    },
                    builder: (context, state) => state.isListening
                        ? Container(
                            padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.grey.shade200,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                child: Text(
                                  'Your mic is listening...',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ),
                          )
                        : state.lastWords.isNotEmpty
                            ? Container(
                                padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: Colors.grey.shade200,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                    child: Text(
                                      state.lastWords,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ),
                              )
                            : Container(),
                  ),
                  const SizedBox(height: 70),
                ],
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: BlocBuilder<ChatBloc, ChatState>(
          bloc: _chatBloc,
          builder: (context, state) => state.maybeMap(
            orElse: () => Container(),
            loaded: (chat) => !chat.isFinished
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 25.0),
                    child: BlocBuilder<MicBloc, MicState>(
                      builder: (context, state) {
                        final bloc = context.read<MicBloc>();

                        return FloatingActionButton(
                          onPressed: !state.isListening
                              ? () => bloc.add(const MicEvent.start())
                              : () => bloc.add(const MicEvent.stop()), // If not yet listening for speech start, otherwise stop
                          child: Icon(!state.isListening ? Icons.mic_off_outlined : Icons.mic_none),
                          backgroundColor: !state.isListening ? const Color(0xff2972ff) : Colors.red,
                        );
                      },
                    ),
                  )
                : Container(),
          ),
        ),
      ),
    );
  }

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(create: (_) => getIt<MicBloc>(), child: this);
  }
}
