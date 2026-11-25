# Merge the price lists in content/prices/sources into content/prices/wine_prices.csv:
# one row per wine + vintage + bottle size, duplicates merged, prices averaged across shops.
# Sources: shopify_shops.csv (every Shopify shop, rebuilt by shopify_to_sources.py from the shop-data branch) and the
# older per-source CSVs for shops that are not on Shopify (UK supermarkets via trolley.co.uk, English wineries) or that
# the last harvest could not reach. CaskCartel and other resellers are never used.
# Run: python3 tools/prices/merge_prices.py content/prices/wine_prices.csv
import csv,re,sys,unicodedata,collections,statistics,datetime,os
from urllib.parse import urlparse
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from wine_clean import is_nonwine, pack_count, NOT_PRODUCER, names_in_title, fold as wfold
RATES={'EUR':1.0,'GBP':0.83735,'USD':1.0990,'AUD':1.6487,'CAD':1.5723,'NZD':1.9968,'CHF':0.9223}  # ECB reference rates, 2026-11-20
BLOCKED=('caskcartel','reservebar','wooden-cork','qualityliquorstore','shopwinedirect')
YEAR=re.compile(r'\b(19[0-9]\d|20[0-2]\d)\b'); NV=re.compile(r'\bNV\b|non[- ]vintage|sans mill',re.I)
FMT={'half':375,'half bottle':375,'magnum':1500,'double magnum':3000,'jeroboam':3000,'rehoboam':4500,'methuselah':6000,'imperial':6000,'salmanazar':9000}
def ml(name,size):
    m=re.search(r'(\d+(?:[.,]\d+)?)\s*(ml|cl|l|ltr)\b',size,re.I) or re.search(r'(\d+(?:[.,]\d+)?)\s*(ml|cl|l|ltr)\b',name,re.I)
    if not re.search(r'\d',size or ''):
        for k in sorted(FMT,key=len,reverse=True):
            if re.search(r'\b'+k+r'\b',name,re.I): return FMT[k]
    if not m: return 750
    v=float(m.group(1).replace(',','.')); u=m.group(2).lower()
    return round(v if u=='ml' else v*10 if u=='cl' else v*1000)
STOP=set('the a de du des la le les di del della dei d l and et e y und wine wines vin vino vini red white rose rosé rouge blanc rosso bianco tinto blanco bottle docg doc igt aoc aop do bottle available ml cl nv magnum vintage brut'.split())
def key(name):
    s=unicodedata.normalize('NFKD',name).encode('ascii','ignore').decode().lower()
    s=re.sub(r'\(.*?\)|\b(19|20)\d\d\b|\d+(\.\d+)?\s*(ml|cl|l)\b',' ',s); s=s.replace('chateau ','').replace('domaine ','').replace('dom. ','')
    t=[w for w in re.findall(r'[a-z0-9]+',s) if w not in STOP and len(w)>1]
    return ' '.join(sorted(set(t)))
import csv,re,sys,collections as C,statistics as S,unicodedata
D=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','content','prices')+'/'
SHOP_NAMES=set()
offers=[]; dropped=C.Counter()
def add(region,shop,loc,name,producer,vint,size,price,cur,instock,url,cased=False):
    if any(b in url for b in BLOCKED): dropped['reseller']+=1; return
    name=re.sub(r'\s*\|\s*',' ',name).strip()
    if is_nonwine(name): dropped['not wine']+=1; return
    if not cased and pack_count(name)!=1: dropped['case or pack']+=1; return
    producer=(producer or '').strip()
    if producer and (NOT_PRODUCER.match(wfold(producer).strip()) or wfold(producer).strip() in SHOP_NAMES): producer=''
    if producer and not names_in_title(producer,name): name=f'{producer} {name}'
    y=YEAR.search(name); vint=vint or (y.group(1) if y else ('NV' if NV.search(name) else ''))
    v=ml(name,size or '')
    if v not in (187,200,250,375,500,620,750,1000,1500,2250,3000,4500,6000,9000,12000,15000,18000): dropped['odd size']+=1; return
    k=key(name)
    if len(k.split())<2: dropped['name too short']+=1; return
    try: price=float(price)
    except ValueError: return
    if price<=0: return
    offers.append(dict(region=region,shop=shop,location=loc,name=name,producer=producer,vintage=vint,size=v,price=price,cur=cur,
        eur=price/RATES[cur],instock=instock,url=url,key=k))
host=lambda u: urlparse(u).netloc
SH=D+'sources/shopify_shops.csv'
harvested=set()
if os.path.exists(SH):
    rows=list(csv.DictReader(open(SH,encoding='utf-8')))
    harvested={host(x['url']) for x in rows}
    SHOP_NAMES|={wfold(x['shop']).strip() for x in rows}
    for x in rows:
        add(x['sold_in'],x['shop'],x['location'],x['wine_name'],x['producer'],x['vintage'],x['size'],x['price'],x['currency'],x['in_stock'],x['url'],cased=True)
print('shopify offers',len(offers),'from',len(harvested),'shops')
SHOP_NAMES|={'tesco',"sainsbury's",'morrisons','asda','waitrose','aldi','iceland','zachys','hedonism wines','sotheby\'s wine','crush wine & spirits'}
old=lambda u: host(u) not in harvested
for x in csv.DictReader(open(D+'sources/uk_supermarkets.csv')):
    add('UK supermarket',x['supermarket'],'UK',x['wine_name'],x['brand'],x['vintage'],x['size'] or '75cl',x['price_gbp'],'GBP','yes',x['trolley_url'])
for x in csv.DictReader(open(D+'sources/us_wine_shops.csv')):
    if old(x['url']): add('US wine shop',x['shop'],x['location'],x['wine_name'],x['producer'],x['vintage'],x['size'],x['price_usd'],'USD',x['in_stock'],x['url'])
for x in list(csv.DictReader(open(D+'sources/europe_wine_shops.csv')))+list(csv.DictReader(open(D+'sources/more_wine_shops.csv')))+list(csv.DictReader(open(D+'sources/more_wine_shops_2.csv'))):
    if old(x['url']): add({'UK':'UK wine shop','US':'US wine shop','Australia':'Australia wine shop','Canada':'Canada wine shop','Zealand':'New Zealand wine shop','Ireland':'Ireland wine shop','Switzerland':'Switzerland wine shop','wine)':'UK wine shop'}.get(x['location'].split()[-1],'EU wine shop'),x['shop'],x['location'],x['wine_name'],x['producer'],x['vintage'],x['size'],x['price'],x['currency'],x['in_stock'],x['url'])
print('dropped',dict(dropped))
print('offers',len(offers))
# group: exact key+vintage+size first (merges same-shop duplicates), then fuzzy across shops
parent=list(range(len(offers))); shops=[{o['shop']} for o in offers]
def find(i):
    while parent[i]!=i: parent[i]=parent[parent[i]]; i=parent[i]
    return i
def union(a,b,allow_same):
    a,b=find(a),find(b)
    if a==b: return
    if not allow_same and shops[a]&shops[b]: return
    parent[a]=b; shops[b]|=shops[a]
ex={}
for i,o in enumerate(offers):
    k=(o['key'],o['vintage'],o['size'])
    if k in ex: union(i,ex[k],True)
    else: ex[k]=i
buckets=C.defaultdict(list)
for i,o in enumerate(offers): buckets[(o['vintage'],o['size'])].append((i,set(o['key'].split())))
for b_,items in buckets.items():
    idx=C.defaultdict(list)
    for i,t in items:
        for w in t: idx[w].append((i,t))
    for i,t in items:
        for w in sorted(t,key=lambda w:len(idx[w]))[:2]:
            if len(idx[w])>3000: continue
            for j,u in idx[w]:
                if j<=i or offers[j]['shop']==offers[i]['shop']: continue
                inter=len(t&u); jac=inter/len(t|u)
                if jac>=0.75 or (inter>=3 and inter==min(len(t),len(u)) and jac>=0.6): union(i,j,False)
G=C.defaultdict(list)
for i in range(len(offers)): G[find(i)].append(offers[i])
def clean(n):
    n=re.sub(r'\((?:[^)]*\b(?:ml|cl|l|available|NV|19\d\d|20\d\d)\b[^)]*)\)','',n,flags=re.I)
    n=re.sub(r'\b\d+(?:\.\d+)?\s*(ml|cl|ltr|l)\b','',n,flags=re.I)
    n=re.sub(r'(,\s*)?\b(19\d\d|20[0-2]\d|NV)\b','',n)
    n=re.sub(r'\s+-\s+(Rouge|Blanc|Rosé)\s*$','',n.strip())
    n=re.sub(r'\(\s*\)','',n)
    return re.sub(r'\s{2,}',' ',re.sub(r'[\s,\-–]+$','',n)).strip(' ,-')
out=[]
for xs in G.values():
    live=[o for o in xs if o['instock']=='yes'] or xs
    per={}
    for o in sorted(live,key=lambda o:o['eur']): per.setdefault(o['shop'],o)  # one price per shop (lowest)
    p=[o['eur'] for o in per.values()]; med=S.median(p)
    use=[o for o in per.values() if med/2.5<=o['eur']<=med*2.5]
    pe=[o['eur'] for o in use]; avg=S.mean(pe)
    names=C.Counter(clean(o['name']) for o in xs)
    name=sorted(names.items(),key=lambda kv:(-kv[1],abs(len(kv[0])-45)))[0][0]
    prod=C.Counter(o['producer'] for o in xs if o['producer']).most_common(1)
    out.append({'wine':name,'producer':prod[0][0] if prod else '','vintage':xs[0]['vintage'],'size_ml':xs[0]['size'],
      'avg_price_gbp':f"{avg*RATES['GBP']:.2f}",'avg_price_eur':f'{avg:.2f}','avg_price_usd':f"{avg*RATES['USD']:.2f}",
      'min_price_gbp':f"{min(pe)*RATES['GBP']:.2f}",'max_price_gbp':f"{max(pe)*RATES['GBP']:.2f}",
      'shops_count':len(use),'in_stock':'yes' if any(o['instock']=='yes' for o in xs) else 'no',
      'sold_in':' / '.join(sorted({o['region'] for o in xs})),
      'prices':' ; '.join(f"{o['shop']} ({o['location']}): {o['price']:.2f} {o['cur']}" for o in sorted(use,key=lambda o:o['eur'])),
      'cheapest_link':min(use,key=lambda o:o['eur'])['url'],
      'price_note':'',
      'links':' ; '.join(f"{o['shop']}: {o['url']}" for o in sorted(use,key=lambda o:o['eur']))})
# owner's manual overrides (content/prices/sources/manual_overrides.csv): the price becomes the given one and its link the cheapest
_ov = D + 'sources/manual_overrides.csv'
if os.path.exists(_ov):
    for m in csv.DictReader(open(_ov)):
        eur = float(m['price']) / RATES[m['currency']]; hit = 0
        for r in out:
            if re.search(m['match'], unicodedata.normalize('NFKD', r['wine']).encode('ascii', 'ignore').decode(), re.I) and r['vintage'] == m['vintage'] and str(r['size_ml']) == m['size_ml']:
                shop = f"{m['shop']} ({m['location']}): {float(m['price']):.2f} {m['currency']}"
                r.update({'avg_price_gbp': f"{eur*RATES['GBP']:.2f}", 'avg_price_eur': f'{eur:.2f}', 'avg_price_usd': f"{eur*RATES['USD']:.2f}",
                          'min_price_gbp': f"{eur*RATES['GBP']:.2f}", 'in_stock': 'yes', 'cheapest_link': m['url'],
                          'prices': shop + ' ; ' + r['prices'], 'links': f"{m['shop']}: {m['url']} ; " + r['links']})
                r['shops_count'] = int(r['shops_count']) + 1; hit += 1
        if not hit and m.get('wine'):   # not sold by any listed shop: add it
            out.append({'wine': m['wine'], 'producer': m.get('producer', ''), 'vintage': m['vintage'], 'size_ml': int(m['size_ml']),
                'avg_price_gbp': f"{eur*RATES['GBP']:.2f}", 'avg_price_eur': f'{eur:.2f}', 'avg_price_usd': f"{eur*RATES['USD']:.2f}",
                'min_price_gbp': f"{eur*RATES['GBP']:.2f}", 'max_price_gbp': f"{eur*RATES['GBP']:.2f}", 'shops_count': 1, 'in_stock': 'yes',
                'sold_in': 'UK wine shop', 'prices': f"{m['shop']} ({m['location']}): {float(m['price']):.2f} {m['currency']}",
                'cheapest_link': m['url'], 'links': f"{m['shop']}: {m['url']}"}); hit = 'added'
        print('override', m['match'], m['vintage'], '->', hit, 'row(s)')
out.sort(key=lambda r:(re.sub(r'^[^a-z0-9]+','',unicodedata.normalize('NFKD',r['wine']).encode('ascii','ignore').decode().lower()),r['vintage'],r['size_ml']))
cols=list(out[0].keys())
w=csv.DictWriter(open(sys.argv[1],'w',newline=''),fieldnames=cols); w.writeheader(); w.writerows(out)
print('wines',len(out),'multi-shop',C.Counter(min(r['shops_count'],5) for r in out),'in stock',sum(r['in_stock']=='yes' for r in out))
