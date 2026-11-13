#!/usr/bin/env python3
"""Original concise educational summaries and explicitly dated championship facts.
No third-party prose, portraits, web pages or application code is copied.
"""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
laws='https://handbook.fide.com/chapter/E012023'
history='https://en.wikipedia.org/wiki/History_of_chess'
champions='https://en.wikipedia.org/wiki/World_Chess_Championship'
facts=[]
def fact(id,title,detail,category,metric=None,symbol='lightbulb.fill',source=history,diagram=None):
 facts.append(dict(id=id,title=title,detail=detail,category=category,metric=metric,symbol=symbol,source=source,diagram=diagram))
fact('squares','A small board, huge possibilities','An 8×8 board has 64 squares, split evenly between light and dark.','Numbers','64','square.grid.3x3.fill',laws)
fact('pieces','Two tiny armies','Each side starts with 16 pieces: eight pawns and eight other pieces.','Pieces','32','person.2.fill',laws)
fact('first-moves','Twenty ways to begin','White has 16 pawn moves and four knight moves in the starting position.','Numbers','20','arrow.triangle.branch',laws)
fact('first-pair','One move each','After White and Black have each moved once, 400 distinct positions are possible.','Numbers','400','square.grid.3x3.fill',laws)
fact('shannon','More than a lifetime of games','Shannon’s famous rough game-tree estimate is about 10¹²⁰. It is an estimate, not an exact count.','Numbers','≈10¹²⁰',source='https://en.wikipedia.org/wiki/Shannon_number')
fact('knight-reach','The knight’s eight exits','From a central square on an empty board, a knight can reach eight squares.','Pieces','8',source=laws,diagram='n')
fact('rook-reach','Straight-line specialist','On an empty board, a rook has 14 destinations from any square.','Pieces','14',source=laws,diagram='r')
fact('bishop-reach','Diagonal specialist','A centrally placed bishop can reach 13 squares on an empty board.','Pieces','13',source=laws,diagram='b')
fact('queen-reach','Maximum mobility','A central queen can reach 27 squares on an otherwise empty board.','Pieces','27',source=laws,diagram='q')
fact('king-reach','One step, every direction','A central king has eight neighboring squares, though attacks can make them illegal.','Pieces','8',source=laws,diagram='k')
fact('bishop-color','A lifetime on one color','A bishop stays on its starting square color for the whole game.','Pieces',source=laws,diagram='b')
fact('knight-color','Always changing color','Every knight move lands on the opposite square color.','Pieces',source=laws,diagram='n')
fact('promotion','A pawn chooses its future','Promotion may produce a queen, rook, bishop or knight—even if none has been captured.','Rules','4',source=laws)
fact('underpromotion','Sometimes a queen is too much','Underpromotion can avoid stalemate or deliver a knight fork.','Rules',source=laws)
fact('nine-queens','A theoretical royal crowd','One side can theoretically have nine queens: the original plus eight promoted pawns.','Numbers','9',source=laws)
fact('en-passant','A one-move window','En passant is available only immediately after the opponent’s qualifying two-square pawn advance.','Rules',source=laws)
fact('castle-check','The king’s safe passage','You cannot castle out of, through, or into check.','Rules',source=laws)
fact('castle-rook','An attacked rook can still castle','A rook being attacked does not by itself prevent castling.','Rules',source=laws)
fact('stalemate','No move, no check','In standard chess, no legal move without being in check is stalemate: a draw.','Rules',source=laws)
fact('threefold','Three appearances, one claim','Threefold repetition can be claimed; the repeated positions need not be consecutive.','Rules','3',source=laws)
fact('fivefold','Five means automatic','Fivefold repetition ends a standard game automatically under FIDE rules.','Rules','5',source=laws)
fact('fifty','A claim, not always an ending','The 50-move rule can be claimed after 50 moves by each side without a pawn move or capture.','Rules','50',source=laws)
fact('seventy-five','The automatic move limit','After 75 such moves by each side, the game is drawn; checkmate on the last move takes priority.','Rules','75',source=laws)
fact('same-position','Same pieces is not enough','Repetition also depends on whose turn it is and the available castling and en-passant rights.','Rules',source=laws)
fact('checkmate-first','The board decides first','A legal move delivering checkmate ends the game immediately.','Rules',source=laws)
fact('chess960','A different first position','Chess960 has 960 starts; bishops begin on opposite colors, with the king between the rooks.','Numbers','960',source='https://en.wikipedia.org/wiki/Fischer_random_chess')
fact('two-knights','Mate possible, force impossible','Two knights cannot force checkmate against a bare king with best defense.','Pieces',source='https://en.wikipedia.org/wiki/Two_knights_endgame')
fact('bishop-knight','The right corner matters','Bishop-and-knight mate drives the king toward a corner matching the bishop’s color.','Pieces',source='https://en.wikipedia.org/wiki/Bishop_and_knight_checkmate')
fact('wrong-bishop','One pawn can change everything','A rook pawn and the wrong-colored bishop can fail to beat a lone king.','Pieces',source='https://en.wikipedia.org/wiki/Wrong_bishop')
fact('opposition','Kings fight without touching','Endgame opposition can force the other king to yield ground.','Pieces',source='https://en.wikipedia.org/wiki/Opposition_(chess)')
fact('zugzwang','The trouble with having a turn','In zugzwang, being required to move makes your position worse.','Pieces',source='https://en.wikipedia.org/wiki/Zugzwang')
fact('chaturanga','An ancient ancestor','Chess traces its roots to chaturanga in India, around the sixth century.','Origins','≈600','globe.asia.australia.fill')
fact('shatranj','A game crossing borders','Shatranj carried an early form of chess through Persia and the Islamic world.','Origins',symbol='globe.asia.australia.fill')
fact('queen-evolves','The queen gained her power','The modern queen’s long-range movement emerged in Europe in the late fifteenth century.','Origins','≈1500')
fact('lucena','A very old chess book','Lucena’s 1497 book is an early printed source for modern chess rules and positions.','Origins','1497',source='https://en.wikipedia.org/wiki/Luis_Ram%C3%ADrez_de_Lucena')
fact('staunton','The familiar silhouette','The Staunton piece design was introduced in 1849 and named after Howard Staunton.','Origins','1849',source='https://en.wikipedia.org/wiki/Staunton_chess_set')
fact('london1851','A new tournament era','Adolf Anderssen won London 1851, a landmark international chess tournament.','Origins','1851',source='https://en.wikipedia.org/wiki/London_1851_chess_tournament')
fact('morphy','A champion before the official title','Paul Morphy dominated his 1858 European tour before an official world championship existed.','People','1858',source='https://en.wikipedia.org/wiki/Paul_Morphy')
fact('steinitz','The first official world champion','Steinitz defeated Zukertort in the 1886 title match.','People','1886','crown.fill',champions)
fact('lasker','Twenty-seven years at the top','Emanuel Lasker held the world title from 1894 to 1921.','People','27','crown.fill',champions)
fact('capablanca','The chess machine','Capablanca became world champion in 1921, celebrated for clarity and endgame skill.','People','1921','crown.fill',champions)
fact('menchik','A women’s championship pioneer','Vera Menchik won the first Women’s World Championship in 1927.','People','1927','crown.fill',source='https://en.wikipedia.org/wiki/Vera_Menchik')
fact('fide','A federation born in Paris','FIDE was founded in Paris in 1924.','Origins','1924','globe.europe.africa.fill',source='https://en.wikipedia.org/wiki/FIDE')
fact('first-gms','The first official grandmasters','FIDE awarded its first 27 grandmaster titles in 1950.','People','27',source='https://en.wikipedia.org/wiki/Grandmaster_(chess)')
fact('nona','A grandmaster milestone','Nona Gaprindashvili became the first woman awarded the open GM title in 1978.','People','1978',source='https://en.wikipedia.org/wiki/Nona_Gaprindashvili')
fact('polgar','Breaking into the top ten','Judit Polgár reached the world top ten in the open rating list.','People','Top 10',source='https://en.wikipedia.org/wiki/Judit_Polg%C3%A1r')
fact('reykjavik','A match on the world stage','Fischer and Spassky’s 1972 title match took place in Reykjavík, Iceland.','People','1972',source=champions)
fact('marathon-match','Forty-eight games, no winner','The 1984–85 Karpov–Kasparov title match was stopped after 48 games without a champion being decided.','People','48',source=champions)
fact('longest-game','A very long draw','Nikolić–Arsović, Belgrade 1989, lasted 269 moves.','Numbers','269',source='https://en.wikipedia.org/wiki/List_of_world_records_in_chess')
fact('deep-blue','A computer wins a match','In 1997, Deep Blue defeated reigning champion Kasparov in a six-game classical match.','Technology','1997','desktopcomputer',source='https://en.wikipedia.org/wiki/Deep_Blue_versus_Garry_Kasparov')
fact('engines','Searching is not seeing everything','Chess engines search selected continuations; extra time can change the best move.','Technology',symbol='cpu',source='https://en.wikipedia.org/wiki/Computer_chess')
fact('tablebases','Perfect knowledge, limited pieces','An endgame tablebase can give exact results for positions within its piece limit.','Technology',symbol='externaldrive.fill',source='https://en.wikipedia.org/wiki/Endgame_tablebase')
fact('elo','A rating is relative','Elo measures results within a player pool; different pools are not automatically equivalent.','Numbers',symbol='chart.bar.fill',source='https://en.wikipedia.org/wiki/Elo_rating_system')
fact('fide-lists','Ratings arrived much later','Published FIDE Elo lists began long after the first world championship. Early champions have no title-era FIDE rating.','Technology','1971','chart.bar.fill',source='https://en.wikipedia.org/wiki/FIDE_world_rankings')
fact('reunification','One title again','Kramnik’s 2006 victory over Topalov reunited the split world championship.','People','2006','crown.fill',champions)
fact('gukesh','A teenage undisputed champion','Gukesh won the undisputed world title in 2024 at age 18.','People','18','crown.fill',champions)

milestones=[
(600,'An Indian beginning','Chaturanga emerges: an ancestor of modern chess.','globe.asia.australia.fill',history),
(900,'A game travels','Shatranj spreads across cultures and into Europe.','globe.europe.africa.fill',history),
(1497,'The powerful queen era','Lucena’s printed book records an early form of modern chess.','book.closed.fill',history),
(1769,'The Mechanical Turk','A famous apparent chess automaton was secretly operated by a human.','gearshape.fill','https://en.wikipedia.org/wiki/Mechanical_Turk'),
(1849,'The Staunton shape','The familiar tournament-piece design is introduced.','square.grid.3x3.fill',history),
(1851,'London gathers the masters','Anderssen wins a landmark international tournament.','person.3.fill',history),
(1858,'Morphy’s European tour','A brilliant attacking player dominates before the official world title.','bolt.fill',history),
(1886,'The world title begins','Steinitz defeats Zukertort in the first official championship match.','crown.fill',champions),
(1924,'FIDE is founded','A world federation is established in Paris.','globe.europe.africa.fill','https://en.wikipedia.org/wiki/FIDE'),
(1927,'A women’s world title','Vera Menchik wins the inaugural championship.','crown.fill','https://en.wikipedia.org/wiki/Women%27s_World_Chess_Championship'),
(1948,'A title decided by tournament','Botvinnik wins the five-player championship after Alekhine’s death.','person.3.fill',champions),
(1950,'Official GM titles','FIDE awards the first 27 grandmaster titles.','star.fill','https://en.wikipedia.org/wiki/Grandmaster_(chess)'),
(1971,'Published Elo lists','FIDE’s published Elo lists establish a new way to compare results.','chart.bar.fill','https://en.wikipedia.org/wiki/FIDE_world_rankings'),
(1972,'Reykjavík captures attention','Fischer defeats Spassky in a globally watched match.','globe.europe.africa.fill',champions),
(1978,'A milestone for women','Gaprindashvili receives the open grandmaster title.','star.fill','https://en.wikipedia.org/wiki/Nona_Gaprindashvili'),
(1985,'Kasparov takes the crown','The 22-year-old begins a fifteen-year title reign.','crown.fill',champions),
(1993,'Two championship branches','The classical and FIDE titles split.','arrow.triangle.branch',champions),
(1997,'Deep Blue’s breakthrough','A computer defeats the reigning champion in a classical match.','desktopcomputer','https://en.wikipedia.org/wiki/Deep_Blue_versus_Garry_Kasparov'),
(2006,'Reunification','Kramnik defeats Topalov; the world title is reunited.','arrow.triangle.merge',champions),
(2013,'The Carlsen era','Carlsen defeats Anand in Chennai.','crown.fill',champions),
(2023,'Ding wins the tiebreak','Ding Liren becomes champion after a tied classical match.','clock.fill',champions),
(2024,'A teenage champion','Gukesh defeats Ding Liren in Singapore.','crown.fill',champions)]

archive='https://github.com/mainali123/Chess-Dataset/blob/5721c8a71a0f9850d54fe6d5b2d8060abcab1357/World_Chess_Champoinship/'
modern='https://github.com/jimhcyang/ChessAnalytics_wcc_2021_2023/blob/12465f014bb9df49aa3afd8c23500ab2c8d4376c/'
records=[]
def champ(id,name,start,end,track='main',elo=None,year=None,file=None,highlight=''):
 source=archive+file if file else champions
 records.append(dict(id=id,name=name,start=start,end=end,track=track,elo=elo,ratingYear=year,source=source,highlight=highlight))
champ('steinitz','Wilhelm Steinitz',1886,1894,highlight='The first official champion')
champ('lasker','Emanuel Lasker',1894,1921,highlight='A 27-year reign')
champ('capablanca','José Raúl Capablanca',1921,1927,highlight='Renowned for endgame clarity')
champ('alekhine-first','Alexander Alekhine',1927,1935,highlight='Takes the title from Capablanca')
champ('euwe','Max Euwe',1935,1937,highlight='The Dutch mathematician wins')
champ('alekhine-second','Alexander Alekhine',1937,1946,highlight='Regains the title')
champ('botvinnik-first','Mikhail Botvinnik',1948,1957,highlight='Wins the 1948 championship tournament')
champ('smyslov','Vasily Smyslov',1957,1958,highlight='Harmony and endgame mastery')
champ('botvinnik-second','Mikhail Botvinnik',1958,1960,highlight='Wins the return match')
champ('tal','Mikhail Tal',1960,1961,highlight='The Wizard of Riga')
champ('botvinnik-third','Mikhail Botvinnik',1961,1963,highlight='A third title reign')
champ('petrosian','Tigran Petrosian',1963,1969,highlight='Famous for resilient defense')
champ('spassky','Boris Spassky',1969,1972,elo=2660,year=1972,file='WorldChamp1972.pgn',highlight='An exceptionally versatile player')
champ('fischer','Bobby Fischer',1972,1975,elo=2785,year=1972,file='WorldChamp1972.pgn',highlight='Wins in Reykjavík')
champ('karpov','Anatoly Karpov',1975,1985,elo=2725,year=1978,file='WorldChamp1978.pgn',highlight='Awarded the title; defends it in 1978')
champ('kasparov','Garry Kasparov',1985,2000,elo=2700,year=1985,file='WorldChamp1985.pgn',highlight='Classical title branch after 1993')
champ('kramnik','Vladimir Kramnik',2000,2007,elo=2770,year=2000,file='WorldChamp2000.pgn',highlight='Reunites the title in 2006')
champ('anand','Viswanathan Anand',2007,2013,elo=2792,year=2007,file='WorldChamp2007.pgn',highlight='Wins the unified title tournament')
champ('carlsen','Magnus Carlsen',2013,2023,elo=2855,year=2021,highlight='Five successful title matches')
records[-1]['source']=modern+'WCC2021.pgn'
champ('ding','Ding Liren',2023,2024,elo=2788,year=2023,highlight='Wins in rapid tiebreaks')
records[-1]['source']=modern+'WCC2023.pgn'
champ('gukesh','Gukesh D',2024,None,elo=2783,year=2024,highlight='Wins the title at 18')
records[-1]['source']='https://ratings.fide.com/profile/46616543/calculations'
for args in [
('fide-karpov','Anatoly Karpov',1993,1999,2760,1993,'FideChamp1993.pgn'),
('fide-khalifman','Alexander Khalifman',1999,2000,2628,1999,'FideChamp1999.pgn'),
('fide-anand','Viswanathan Anand',2000,2002,2762,2000,'FideChamp2000.pgn'),
('fide-ponomariov','Ruslan Ponomariov',2002,2004,2727,2002,'FideChamp2002.pgn'),
('fide-kasimdzhanov','Rustam Kasimdzhanov',2004,2005,2652,2004,'FideChamp2004.pgn'),
('fide-topalov','Veselin Topalov',2005,2006,2788,2005,'FideChamp2005.pgn')]:
 id,name,start,end,elo,year,file=args
 champ(id,name,start,end,'split',elo,year,file,'FIDE title during the split')

content=dict(coverageThrough=2024,ratingNote='Recorded event Elo with its year—not peak ratings. — means no contemporaneous event rating supplied. Early titles predate published FIDE lists.',facts=facts,milestones=[dict(id=f'event-{year}',year=year,title=title,detail=detail,symbol=symbol,source=source) for year,title,detail,symbol,source in milestones],champions=records)
(ROOT/'NovaChess/Core/Resources/Learning.json').write_text(json.dumps(content,ensure_ascii=False,indent=2)+'\n')
print(f'{len(facts)} facts, {len(milestones)} milestones, {len(records)} championship reigns')
