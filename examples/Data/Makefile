MODULES    := Counter CounterF Stack Reverse Queue Array Stream AssocListModel \
	AssocListOrdModel FiniteMap RefFiniteMap HashTable \
	BinarySearchTree \
	JahobAssocList BinomialTree LinkedListSeg FiniteMap2 \


VS         := $(MODULES:%=%.v)

.SUFFIXES: .v .vo

.PHONY: coq clean

coq: Makefile.coq
	$(MAKE) -f Makefile.coq

R := -R ../../src/coq Ynot -R . Data

Makefile.coq: Makefile $(VS)
	coq_makefile $(VS) \
		COQC = "coqc $(R)" \
		COQDEP = "coqdep $(R)" \
		-o Makefile.coq

clean:: Makefile.coq
	$(MAKE) -f Makefile.coq clean
	rm -f Makefile.coq .depend

.v.vo: $.v
	coqc $(R) -q  -I . $(<:.v=)
