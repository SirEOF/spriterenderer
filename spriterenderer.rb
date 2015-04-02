#!/usr/bin/ruby

# A raw bitmap renderer
# can be used to visually determine offset of a raw bitmap / sprite offset in a bigger file
# needs ruby-gtk2
# type ? for help

# License: WtfPLv2
# Author: (c) Y. Guillot, 11/2009
# Changelog: 2015: fixes for ruby2, add nBpp

require 'gtk2'

abort 'no file given' if not filename = ARGV.shift

buf = File.open(filename, 'rb') { |fd| fd.read }
off = 0
sz = 1
vflip = false
nBpp = 1

w = Gtk::Window.new
render = Gtk::DrawingArea.new
w.signal_connect('destroy') { Gtk.main_quit }
w.add render

w_width = w_height = 1

redraw = lambda { render.window.invalidate Gdk::Rectangle.new(0, 0, 100000, 100000), false }

render.set_events Gdk::Event::ALL_EVENTS_MASK
render.signal_connect('size_allocate') { |ww, alloc| redraw[] if render.window }

cols = []
render.signal_connect('realize') {
	256.times { |t|
		c = t << 8 | t
		cols[t] = Gdk::Color.new(c, c, c)
	}
	cols.each { |c| render.window.colormap.alloc_color(c, true, true) }
}

w.signal_connect('key_press_event') { |ww, ev|
	case ev.keyval
	when ?o.ord; off += 1
		 off = buf.size - w_width*w_height*nBpp if off >= buf.size - w_width*w_height*nBpp
		 off = 0 if off < 0
	when ?O.ord; off -= 1
		 off = 0 if off < 0
	when ?p.ord; off += w_width*w_height*nBpp
		 off = buf.size - w_width*w_height*nBpp if off >= buf.size - w_width*w_height*nBpp
		 off = 0 if off < 0
	when ?P.ord; off -= w_width*w_height*nBpp
		 off = 0 if off < 0
	when ?f.ord; vflip = !vflip
	when ?w.ord; w.resize(w.size[0]+sz, w.size[1])
	when ?W.ord; w.resize(w.size[0]-sz, w.size[1])
	when ?h.ord; w.resize(w.size[0], w.size[1]+sz)
	when ?H.ord; w.resize(w.size[0], w.size[1]-sz)
	when ?z.ord; sz += 1
	when ?Z.ord; sz -= 1
		 sz = 1 if sz <= 0
	when ?b.ord; nBpp += 1
	when ?B.ord; nBpp -= 1 if nBpp > 1
	when ??.ord; puts <<EOS
file: #{filename.inspect}
 fileoffset #{'0x%X' % off}, pixsz #{w_width}x#{w_height}
help:
 oOpP/mousewheel: offset in file
 wWhH: change window size
 zZ: zoom
 bB: Bpp
 f: vertical flip
 ?: info
EOS
	end
	w.title = "#{filename} +#{'%x' % off} #{w_width}x#{w_height}x#{nBpp}"
	redraw[]
	true
}

render.signal_connect('scroll_event') { |ww, ev|
	case ev.direction
	when Gdk::EventScroll::Direction::UP
		off -= 8*w_width
		off = 0 if off < 0
	when Gdk::EventScroll::Direction::DOWN
		off += 8*w_width
		off = buf.size-1 if off >= buf.size
	end
	redraw[]
}

render.signal_connect('expose_event') {
	ww = render.window
	gc = Gdk::GC.new(ww)
	w_w = render.allocation.width
	w_h = render.allocation.height
	w_width = w_w/sz
	w_height = w_h/sz

	x = 0
	y = 0
	y = w_h-sz if vflip
msg = "#{w_width}x#{w_height}x#{nBpp}@#{off}"
$stdout.print "#{msg}...            \r"
$stdout.flush
	curbyteoff = 0
	buf[off, w_width*(w_height+1)*nBpp].each_byte { |o|
		curbyteoff += 1
		next if curbyteoff < nBpp
		curbyteoff = 0
		gc.set_foreground cols[o]
		ww.draw_rectangle(gc, true, x, y, sz, sz)

		x += sz
		if x > w_w-sz
			x = 0
			if vflip
				y -= sz
				break if y < 0
			else
				y += sz
				break if y > w_h
			end
		end
	}
$stdout.print "#{msg}             \r"
$stdout.flush

	true
}

w.title = "#{filename} +0"
w.show_all

Gtk.main

