function n(e){let o=null;document.addEventListener("astro:page-load",()=>{o?.abort(),o=new AbortController,e(o.signal)})}export{n as o};
