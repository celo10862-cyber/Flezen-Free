import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'services/media_link_resolver.dart';

void main() => runApp(const FlezenFreeApp());

const accent = Color(0xFFB8A1FF);
const page = Color(0xFF09090D);
const panel = Color(0xFF191820);

class FlezenFreeApp extends StatelessWidget {
  const FlezenFreeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flezen Free',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: page,
          colorScheme: ColorScheme.fromSeed(
            seedColor: accent,
            brightness: Brightness.dark,
            surface: page,
          ),
          useMaterial3: true,
        ),
        home: const MainShell(),
      );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 0;
  final history = <String>[];
  final bookmarks = <String>[];
  final downloads = <String>[];
  final input = TextEditingController();

  void openLink(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        !{'http', 'https'}.contains(uri.scheme)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid http or https link.')),
      );
      return;
    }
    setState(() {
      history.remove(value);
      history.insert(0, value);
    });
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(url: value),
    ));
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        controller: input,
        history: history,
        onOpen: openLink,
        onBookmark: (value) => setState(() {
          if (!bookmarks.contains(value)) bookmarks.insert(0, value);
        }),
      ),
      LinkListScreen(
        title: 'Bookmarks',
        icon: Icons.bookmark_outline,
        items: bookmarks,
        onOpen: openLink,
        empty: 'Your saved links will appear here.',
      ),
      LinkListScreen(
        title: 'Downloads',
        icon: Icons.download_outlined,
        items: downloads,
        onOpen: openLink,
        empty: 'Your downloaded media will appear here.',
      ),
      LinkListScreen(
        title: 'History',
        icon: Icons.history,
        items: history,
        onOpen: openLink,
        empty: 'Recently opened links will appear here.',
      ),
    ];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF121117),
        indicatorColor: accent.withValues(alpha: .18),
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.bookmark_border),
              selectedIcon: Icon(Icons.bookmark),
              label: 'Saved'),
          NavigationDestination(
              icon: Icon(Icons.download_outlined),
              selectedIcon: Icon(Icons.download),
              label: 'Downloads'),
          NavigationDestination(
              icon: Icon(Icons.history),
              selectedIcon: Icon(Icons.history),
              label: 'History'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.history,
    required this.onOpen,
    required this.onBookmark,
  });
  final TextEditingController controller;
  final List<String> history;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onBookmark;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(14)),
              child:
                  const Icon(Icons.play_arrow_rounded, color: accent, size: 30),
            ),
            const SizedBox(width: 12),
            const Text('Flezen',
                style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.7)),
            const Text(' Free',
                style: TextStyle(
                    fontSize: 17, color: accent, fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
                onPressed: () => showAboutDialog(
                      context: context,
                      applicationName: 'Flezen Free',
                      applicationVersion: '1.0.0',
                      children: const [
                        Text('An ad-free media link player.')
                      ],
                    ),
                icon: const Icon(Icons.settings_outlined)),
          ]),
          const SizedBox(height: 28),
          const Text('Play your link',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Paste a direct media link to start playing.',
              style: TextStyle(color: Colors.white.withValues(alpha: .6))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10)),
            child: Column(children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'Paste video or audio URL',
                  prefixIcon: Icon(Icons.link, color: accent),
                  border: InputBorder.none,
                ),
                onSubmitted: onOpen,
              ),
              Row(children: [
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF17121F)),
                  onPressed: () => onOpen(controller.text),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play now'),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 28),
          const Text('Recent history',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (history.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
              decoration: BoxDecoration(
                  color: panel, borderRadius: BorderRadius.circular(18)),
              child: const Column(children: [
                Icon(Icons.history, size: 34, color: accent),
                SizedBox(height: 10),
                Text('No history yet',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('Links you play will show up here.',
                    style: TextStyle(color: Colors.white54)),
              ]),
            )
          else
            ...history.take(5).map((value) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                      backgroundColor: panel,
                      child: Icon(Icons.play_arrow, color: accent)),
                  title: Text(value,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => onOpen(value),
                  trailing: IconButton(
                    icon: const Icon(Icons.bookmark_add_outlined),
                    onPressed: () => onBookmark(value),
                  ),
                )),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF30264A), Color(0xFF1B1827)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(children: [
              Icon(Icons.shield_moon_outlined, color: accent, size: 30),
              SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Simple. Clean. Ad-free.',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('No premium screen or advertising in this edition.',
                        style: TextStyle(color: Colors.white70)),
                  ])),
            ]),
          ),
        ],
      );
}

class LinkListScreen extends StatelessWidget {
  const LinkListScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    required this.onOpen,
    required this.empty,
  });
  final String title;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String> onOpen;
  final String empty;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: accent, size: 27),
            const SizedBox(width: 10),
            Text(title,
                style:
                    const TextStyle(fontSize: 25, fontWeight: FontWeight.bold))
          ]),
          const SizedBox(height: 20),
          if (items.isEmpty)
            Expanded(
                child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: accent, size: 52),
              const SizedBox(height: 14),
              const Text('Nothing here yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(empty,
                  style: const TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center),
            ])))
          else
            Expanded(
                child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white12),
              itemBuilder: (context, index) => ListTile(
                leading: const CircleAvatar(
                    backgroundColor: panel,
                    child: Icon(Icons.play_arrow, color: accent)),
                title: Text(items[index],
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => onOpen(items[index]),
              ),
            )),
        ]),
      );
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.url});
  final String url;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? player;
  ResolvedMedia? media;
  String? error;
  bool loading=true, downloading=false;
  @override
  void initState(){super.initState();_resolveAndPlay();}
  Future<void> _resolveAndPlay() async {
    try {
      final result=await MediaLinkResolver().resolve(widget.url);
      if(!mounted)return; media=result;
      final controller=VideoPlayerController.networkUrl(Uri.parse(result.url),httpHeaders:result.headers);
      player=controller; await controller.initialize(); if(!mounted)return; await controller.play(); setState(()=>loading=false);
    } catch(e) { if(mounted)setState(() { loading=false; error=e is MediaResolutionException?e.message:'Could not resolve or play this link. The server may require an authorized session or use an unsupported stream.'; }); }
  }
  Future<void> _openOriginal() async {final u=Uri.parse(widget.url);if(await canLaunchUrl(u))await launchUrl(u,mode:LaunchMode.externalApplication);}
  Future<void> _download() async {
    final m=media;if(m==null||downloading)return;setState(()=>downloading=true);
    try {final dir=await getApplicationDocumentsDirectory();final name=(m.fileName?.isNotEmpty==true?m.fileName:'media_file')!.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'),'_');await Dio().download(m.url,'${dir.path}/$name',options:Options(headers:m.headers));if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Saved to app storage: $name')));}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Download failed. This source may prohibit downloading or require a session.')));}
    finally{if(mounted)setState(()=>downloading=false);}
  }
  @override
  void dispose(){player?.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Now playing'),actions:[IconButton(onPressed:downloading||media==null?null:_download,icon:downloading?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.download_outlined)),IconButton(onPressed:_openOriginal,icon:const Icon(Icons.open_in_browser))]),body:Center(child:Padding(padding:const EdgeInsets.all(20),child:loading?const Column(mainAxisSize:MainAxisSize.min,children:[CircularProgressIndicator(color:accent),SizedBox(height:14),Text('Finding a playable media stream…',style:TextStyle(color:Colors.white70))]):error!=null?Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.info_outline,color:accent,size:48),const SizedBox(height:14),Text(error!,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white70)),const SizedBox(height:14),OutlinedButton.icon(onPressed:_openOriginal,icon:const Icon(Icons.open_in_browser),label:const Text('Open original page'))]):Column(mainAxisSize:MainAxisSize.min,children:[AspectRatio(aspectRatio:player!.value.aspectRatio>0?player!.value.aspectRatio:16/9,child:VideoPlayer(player!)),const SizedBox(height:18),VideoProgressIndicator(player!,allowScrubbing:true,colors:const VideoProgressColors(playedColor:accent)),IconButton(onPressed:()=>setState(()=>player!.value.isPlaying?player!.pause():player!.play()),icon:Icon(player!.value.isPlaying?Icons.pause_circle:Icons.play_circle,size:48,color:accent)),if(media?.isHls==true||media?.isDash==true)Text(media!.isHls?'HLS stream':'DASH stream',style:const TextStyle(color:Colors.white54))]))));
}
