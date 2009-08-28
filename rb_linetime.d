#pragma D option quiet

this string str;

dtrace:::BEGIN
{
        printf("Tracing... Hit Ctrl-C to end.\n");
        depth = 0;
}

ruby$target:::function-entry
{
        self->depth++;
        self->start[copyinstr(arg0), copyinstr(arg1), self->depth] = timestamp;
}

ruby$target:::function-return
/(this->class = copyinstr(arg0)) != NULL && \
 (this->func  = copyinstr(arg1)) != NULL && \
 self->start[this->class, this->func, self->depth]/
{
        this->elapsed = timestamp - self->start[this->class, this->func, self->depth];
	
	this->file = copyinstr(arg2);
	this->line = arg3;
        @num[this->file, this->line] = count();
        @eavg[this->file, this->line] = avg(this->elapsed);
        @esum[this->file, this->line] = sum(this->elapsed);

        self->start[this->class, this->func, self->depth] = 0;
        self->depth--;
}

dtrace:::END
{
        normalize(@eavg, 1000);
        normalize(@esum, 1000);
        setopt("aggsortpos", "2");
        printf("%-33s %123s\n", "___ OVERLAP TIMES: ___",
            "______ ELAPSED _____");
        printf("%-120s %5s %6s %10s %12s\n", "FILE", "LINE",
            "COUNT", "AVG(us)", "SUM(us)");
        printa("%-120.120s %5d %@6d %@10d %@12d\n", @num, @eavg, @esum);
}
